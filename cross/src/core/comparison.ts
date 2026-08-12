/**
 * Planning and reading a blocked comparison: phase two.
 *
 * Passive observation does not produce what would be needed. In the 2020 diary
 * only 19 ingredients out of 142 reached ten exposures, and those exposures
 * happened whenever they happened, alongside other foods, at no known dose. A
 * planned comparison forces exposure to a chosen target, in blocks of known
 * length, alternating with control blocks.
 *
 * The structure comes from published, citable reintroduction protocols: one
 * target at a time, consecutive blocks, a gap in between, and nothing
 * reintroduced for good until every comparison is closed. The durations do not.
 * In the clinic a block is three days; here it is longer, for two independent
 * reasons. The first is in this person's data: daily autocorrelation is +0.51 at
 * one day, +0.16 at three and +0.05 at four, so a three-day gap still carries
 * the echo of the block before. The second is biological: in the published
 * blinded challenge, lactose symptoms appear on day three, so a three-day block
 * is cut off before they could be seen.
 *
 * What this does not do is decide the outcome. In the published protocols a
 * positive is defined by a threshold on a licensed instrument; here the two
 * series are shown side by side with the exact p, the tie convention used and
 * the interval, and the judgement stays with whoever reads it.
 */

import {
  binomialCoefficient,
  signTest,
  wilcoxon,
  signTestPower,
  type SignTestResult,
  type TieConvention,
  type WilcoxonResult,
} from './exact.js';
import { addDays, daysBetween } from './stats.js';
import type { BlockCondition, ComparisonOutcome, HypothesisDirection } from './model.js';

// ---------------------------------------------------------------- scheduling

/**
 * An AB/BA sequence with the order inside each pair decided by the seed.
 *
 * Pairs, because the comparison is paired: every target block has its control
 * block close in time, so a slow drift (a season, a stretch of work) hits both
 * the same way. The order inside the pair alternates at random so the condition
 * does not line up with position in time.
 */
export function sequence(pairs: number, seed: bigint): BlockCondition[] {
  let state = seed === 0n ? 0x9e3779b97f4a7c15n : seed;
  const mask = (1n << 64n) - 1n;
  const next = (): bigint => {
    state = (state ^ ((state << 13n) & mask)) & mask;
    state = state ^ (state >> 7n);
    state = (state ^ ((state << 17n) & mask)) & mask;
    return state;
  };
  const out: BlockCondition[] = [];
  for (let i = 0; i < pairs; i++) {
    if (next() % 2n === 0n) out.push('bersaglio', 'controllo');
    else out.push('controllo', 'bersaglio');
  }
  return out;
}

export interface PlannedBlock {
  index: number;
  condition: BlockCondition;
  from: string;
  to: string;
}

export function plan(
  pairs: number,
  daysPerBlock: number,
  gapDays: number,
  start: string,
  seed: bigint,
): PlannedBlock[] {
  const conditions = sequence(pairs, seed);
  const out: PlannedBlock[] = [];
  let day = start;
  for (let i = 0; i < conditions.length; i++) {
    out.push({
      index: i,
      condition: conditions[i]!,
      from: day,
      to: addDays(day, daysPerBlock - 1),
    });
    day = addDays(day, daysPerBlock + gapDays);
  }
  return out;
}

export function totalDays(pairs: number, daysPerBlock: number, gapDays: number): number {
  const blocks = pairs * 2;
  return blocks * daysPerBlock + Math.max(0, blocks - 1) * gapDays;
}

// -------------------------------------------------------------- feasibility

export interface Feasibility {
  pairs: number;
  totalDays: number;
  pFloor: number;
  /** How many pairs must agree for the result to be significant. */
  agreementsNeeded: number;
  power70: number;
  power80: number;
  power90: number;
  reachable: boolean;
  /** How many pairs it would take to tolerate a single disagreement. */
  pairsToToleranceOne: number;
}

/**
 * The picture to show BEFORE starting.
 *
 * The number that matters is not the minimum detectable difference but the
 * power, and it is almost always depressing: with six pairs and a two-sided
 * hypothesis the test demands unanimity, so even a target that genuinely
 * affects you in eight pairs out of ten has roughly one chance in four of being
 * recognised. Saying it first is the only way the decision to spend two months
 * is an informed one.
 */
export function feasibility(
  pairs: number,
  daysPerBlock: number,
  gapDays: number,
  oneSided: boolean,
  alpha = 0.05,
): Feasibility {
  const pFloor = Math.min(1, Math.pow(2, 1 - pairs) * (oneSided ? 0.5 : 1));
  let needed = pairs + 1;
  for (let k = pairs; k > Math.floor(pairs / 2); k--) {
    let tail = 0;
    for (let i = k; i <= pairs; i++) tail += binomialCoefficient(pairs, i);
    tail /= Math.pow(2, pairs);
    const value = oneSided ? tail : Math.min(1, 2 * tail);
    if (value <= alpha) needed = k;
    else break;
  }
  let tolerance = 0;
  for (let n = pairs; n <= 40; n++) {
    const tail = (binomialCoefficient(n, n - 1) + binomialCoefficient(n, n)) / Math.pow(2, n);
    const value = oneSided ? tail : Math.min(1, 2 * tail);
    if (value <= alpha) {
      tolerance = n;
      break;
    }
  }
  return {
    pairs,
    totalDays: totalDays(pairs, daysPerBlock, gapDays),
    pFloor,
    agreementsNeeded: Math.min(needed, pairs),
    power70: signTestPower(pairs, 0.7, alpha, oneSided) ?? 0,
    power80: signTestPower(pairs, 0.8, alpha, oneSided) ?? 0,
    power90: signTestPower(pairs, 0.9, alpha, oneSided) ?? 0,
    reachable: pFloor <= alpha,
    pairsToToleranceOne: tolerance,
  };
}

// ------------------------------------------------------------------ reading

export interface ObservedDay {
  day: string;
  pain: number | null;
  abnormalDay: boolean | null;
}

export interface BlockValue {
  index: number;
  condition: BlockCondition;
  value: number | null;
  daysUsed: number;
  daysDropped: number;
}

export interface Pair {
  number: number;
  target: number;
  control: number;
}

export function pairDifference(p: Pair): number {
  return p.target - p.control;
}

export type Verdict =
  | 'coerenteConUnEffetto'
  | 'nessunEffettoRilevabile'
  | 'nonConcludente'
  | 'protocolloAlterato'
  | 'incompleta';

export const VERDICT_LABEL: Record<Verdict, string> = {
  coerenteConUnEffetto: 'Consistent with an effect',
  nessunEffettoRilevabile: 'No detectable effect',
  nonConcludente: 'Inconclusive',
  protocolloAlterato: 'Protocol changed after it was frozen',
  incompleta: 'Not finished yet',
};

export interface Reading {
  values: BlockValue[];
  pairs: Pair[];
  sign: SignTestResult | null;
  wilcoxon: WilcoxonResult | null;
  verdict: Verdict;
  /** Pairs lost because one of the two blocks has no usable day. */
  pairsLost: number;
}

export function blockValues(
  blocks: readonly { index: number; condition: BlockCondition; from: string; to: string }[],
  observations: readonly ObservedDay[],
  outcome: ComparisonOutcome,
  daysDroppedAtStart: number,
): BlockValue[] {
  const byDay = new Map(observations.map((o) => [o.day, o]));
  return blocks.map((b) => {
    const days: string[] = [];
    let day = b.from;
    while (day <= b.to) {
      days.push(day);
      day = addDays(day, 1);
    }
    const dropped = Math.min(daysDroppedAtStart, Math.max(0, days.length - 1));
    const usable = days.slice(dropped);
    const values: number[] = [];
    for (const d of usable) {
      const o = byDay.get(d);
      if (!o) continue;
      if (outcome === 'dolore') {
        if (o.pain !== null && o.pain !== undefined) values.push(o.pain);
      } else if (o.abnormalDay !== null && o.abnormalDay !== undefined) {
        values.push(o.abnormalDay ? 1 : 0);
      }
    }
    return {
      index: b.index,
      condition: b.condition,
      value: values.length === 0 ? null : values.reduce((a, c) => a + c, 0) / values.length,
      daysUsed: values.length,
      daysDropped: dropped,
    };
  });
}

/** Pairs blocks two by two, in the order they were planned. */
export function pairUp(values: readonly BlockValue[]): { pairs: Pair[]; lost: number } {
  const ordered = [...values].sort((a, b) => a.index - b.index);
  const pairs: Pair[] = [];
  let lost = 0;
  let number = 1;
  for (let i = 0; i + 1 < ordered.length; i += 2) {
    const a = ordered[i]!;
    const b = ordered[i + 1]!;
    const target = a.condition === 'bersaglio' ? a : b;
    const control = a.condition === 'bersaglio' ? b : a;
    if (target.value !== null && control.value !== null) {
      pairs.push({ number, target: target.value, control: control.value });
    } else {
      lost++;
    }
    number++;
  }
  return { pairs, lost };
}

export function read(options: {
  blocks: readonly { index: number; condition: BlockCondition; from: string; to: string }[];
  observations: readonly ObservedDay[];
  outcome: ComparisonOutcome;
  direction: HypothesisDirection;
  tieConvention: TieConvention;
  daysDroppedAtStart: number;
  plannedPairs: number;
  protocolValid: boolean;
  alpha?: number;
}): Reading {
  const alpha = options.alpha ?? 0.05;
  const values = blockValues(
    options.blocks,
    options.observations,
    options.outcome,
    options.daysDroppedAtStart,
  );
  const { pairs, lost } = pairUp(values);

  if (!options.protocolValid) {
    return { values, pairs, sign: null, wilcoxon: null, verdict: 'protocolloAlterato', pairsLost: lost };
  }
  if (pairs.length < options.plannedPairs) {
    return { values, pairs, sign: null, wilcoxon: null, verdict: 'incompleta', pairsLost: lost };
  }

  const differences = pairs.map(pairDifference);
  const sign = signTest(differences);
  const wil = wilcoxon(differences, options.tieConvention);

  const oneSided = options.direction === 'unilateraleAumento';
  const p = wil ? (oneSided ? wil.pOneSided : wil.pTwoSided) : null;

  let verdict: Verdict;
  if (p !== null && p <= alpha) verdict = 'coerenteConUnEffetto';
  else if (wil && wil.pFloor > alpha) verdict = 'nonConcludente';
  else verdict = 'nessunEffettoRilevabile';

  return { values, pairs, sign, wilcoxon: wil, verdict, pairsLost: lost };
}

export { daysBetween };
