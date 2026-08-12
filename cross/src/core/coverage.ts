/**
 * How much of a day is actually known.
 *
 * This is the measure the 2020 project lacked, and it explains its failure
 * better than any statistical argument: out of 68 days, only 26 had at least
 * three meals recorded. A day with two meals out of six written down is not an
 * observed day, it is a day that is mostly unknown, and treating it as data is
 * the quickest way to build conclusions on nothing.
 *
 * A slot counts as answered even when the answer is "nothing": knowing that
 * someone did not eat is information, not a hole.
 */

import { addDays } from './stats.js';
import { EXPECTED_SLOTS, type Slot } from './model.js';

export interface DayCoverage {
  day: string;
  expectedSlots: number;
  answeredSlots: number;
  events: number;
  hasOutcome: boolean;
  fraction: number;
  complete: boolean;
}

export interface CoverageWindow {
  days: number;
  completeDays: number;
  meanFraction: number;
  daysWithOutcome: number;
  daysWithEvents: number;
  analysable: boolean;
}

/** Below this the app calls a period not analysable rather than showing numbers that look sound. */
export const ANALYSABLE_THRESHOLD = 0.7;

/**
 * Coverage day by day across the whole range, including the days that are
 * entirely empty: a day with nothing in it is the most important thing not to
 * hide.
 */
export function dailyCoverage(options: {
  answeredSlots: ReadonlyMap<string, ReadonlySet<Slot>>;
  eventsPerDay: ReadonlyMap<string, number>;
  daysWithOutcome: ReadonlySet<string>;
  from?: string;
  to?: string;
  expected?: readonly Slot[];
}): DayCoverage[] {
  const expected = options.expected ?? EXPECTED_SLOTS;
  const keys = new Set<string>([
    ...options.answeredSlots.keys(),
    ...options.eventsPerDay.keys(),
    ...options.daysWithOutcome,
  ]);
  if (keys.size === 0 && !options.from) return [];
  const sorted = [...keys].sort();
  const first = options.from ?? sorted[0]!;
  const last = options.to ?? sorted[sorted.length - 1]!;

  const out: DayCoverage[] = [];
  let day = first;
  while (day <= last) {
    const answered = options.answeredSlots.get(day) ?? new Set<Slot>();
    const count = expected.filter((s) => answered.has(s)).length;
    out.push({
      day,
      expectedSlots: expected.length,
      answeredSlots: count,
      events: options.eventsPerDay.get(day) ?? 0,
      hasOutcome: options.daysWithOutcome.has(day),
      fraction: expected.length > 0 ? count / expected.length : 0,
      complete: expected.length > 0 && count >= expected.length,
    });
    day = addDays(day, 1);
  }
  return out;
}

/**
 * Summary over the last `days` calendar days ending at `end`. Days missing from
 * the list count as zero coverage: there are no neutral days, either what
 * happened is known or it is not.
 */
export function coverageWindow(
  coverage: readonly DayCoverage[],
  days: number,
  end: string,
): CoverageWindow {
  const first = addDays(end, -(days - 1));
  const inside = coverage.filter((c) => c.day >= first && c.day <= end);
  const sum = inside.reduce((a, c) => a + c.fraction, 0);
  return {
    days,
    completeDays: inside.filter((c) => c.complete).length,
    meanFraction: days > 0 ? sum / days : 0,
    daysWithOutcome: inside.filter((c) => c.hasOutcome).length,
    daysWithEvents: inside.filter((c) => c.events > 0).length,
    analysable: (days > 0 ? sum / days : 0) >= ANALYSABLE_THRESHOLD,
  };
}
