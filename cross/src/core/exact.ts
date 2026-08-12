/**
 * Exact non-parametric tests for paired comparisons with very few pairs.
 *
 * Exact by enumeration, not approximated: with six pairs any normal
 * approximation is meaningless, and the number that decides everything is not
 * the statistic you choose but 2^n. With k pairs the smallest reachable
 * two-sided p is 2^(1-k), so with five pairs or fewer nothing can be
 * significant, whatever happens. That is worth saying before a comparison
 * starts, not after.
 *
 * The null distribution is built by permuting the signs over the ranks that
 * were actually observed. With ties, and under Pratt's convention, that is not
 * the same as the classic table, and the table is the one that is wrong:
 * `scipy.stats.wilcoxon(mode="exact")` uses the table and returns a different
 * value on those cases. The oracle for the tests is the enumeration of all 2^n
 * sign assignments.
 */

export type TieConvention = 'escludi' | 'pratt';

// ---------------------------------------------------------------- sign test

export interface SignTestResult {
  positive: number;
  negative: number;
  ties: number;
  pairsUsed: number;
  pOneSided: number;
  pTwoSided: number;
  /** The smallest two-sided p reachable with the pairs that are left. */
  pFloor: number;
}

export function binomialCoefficient(n: number, k: number): number {
  if (k < 0 || k > n) return 0;
  let r = 1;
  for (let i = 0; i < Math.min(k, n - k); i++) r = (r * (n - i)) / (i + 1);
  return Math.round(r);
}

export function signTest(differences: readonly number[]): SignTestResult | null {
  let positive = 0;
  let negative = 0;
  let ties = 0;
  for (const d of differences) {
    if (d > 0) positive++;
    else if (d < 0) negative++;
    else ties++;
  }
  const n = positive + negative;
  if (n < 1) {
    // Every difference is zero. Not an error, and in fact the case worth
    // stating in full: the comparison ended with no usable pair at all.
    return {
      positive: 0,
      negative: 0,
      ties,
      pairsUsed: 0,
      pOneSided: 1,
      pTwoSided: 1,
      pFloor: 1,
    };
  }

  const k = Math.min(positive, negative);
  let tail = 0;
  for (let i = 0; i <= k; i++) tail += binomialCoefficient(n, i);
  tail /= Math.pow(2, n);

  let upper = 0;
  for (let i = k; i <= n; i++) upper += binomialCoefficient(n, i);
  upper /= Math.pow(2, n);

  const oneSided = positive > negative ? tail : positive >= negative ? upper : tail;
  return {
    positive,
    negative,
    ties,
    pairsUsed: n,
    pOneSided: oneSided,
    pTwoSided: Math.min(1, 2 * tail),
    pFloor: Math.min(1, Math.pow(2, 1 - n)),
  };
}

// ------------------------------------------------------------------ Wilcoxon

export interface WilcoxonResult {
  wPositive: number;
  wNegative: number;
  pairsUsed: number;
  ties: number;
  convention: TieConvention;
  /** True when the ranks contain ties and the classic table would be wrong. */
  hasTiedRanks: boolean;
  pOneSided: number;
  pTwoSided: number;
  pFloor: number;
  /** Hodges-Lehmann estimator: the median of the Walsh averages. */
  hodgesLehmann: number | null;
  /**
   * Interval bounds with the confidence level that actually exists. With six
   * pairs there is no 95% interval: there are 96.875% and 93.75%. Showing one
   * and calling it 95% would be a lie about a number the reader takes as exact.
   */
  interval: { low: number; high: number; confidence: number } | null;
}

export function averageRanks(values: readonly number[]): number[] {
  const order = values.map((v, i) => [v, i] as const).sort((a, b) => a[0] - b[0]);
  const ranks = new Array<number>(values.length).fill(0);
  let i = 0;
  while (i < order.length) {
    let j = i;
    while (j + 1 < order.length && order[j + 1]![0] === order[i]![0]) j++;
    const mid = (i + 1 + (j + 1)) / 2;
    for (let k = i; k <= j; k++) ranks[order[k]![1]] = mid;
    i = j + 1;
  }
  return ranks;
}

/**
 * Exact null distribution of W by enumerating the 2^n signs, built on the ranks
 * that were actually observed, so it holds with tied ranks and under Pratt too.
 * Keys are doubled to stay integral, because average ranks are multiples of 0.5
 * and floating-point keys would not compare equal.
 */
export function nullDistribution(ranks: readonly number[]): Map<number, number> {
  let d = new Map<number, number>([[0, 1]]);
  for (const r of ranks) {
    const next = new Map<number, number>();
    const step = Math.round(r * 2);
    for (const [sum, weight] of d) {
      next.set(sum, (next.get(sum) ?? 0) + weight);
      next.set(sum + step, (next.get(sum + step) ?? 0) + weight);
    }
    d = next;
  }
  return d;
}

export function walshAverages(x: readonly number[]): number[] {
  const w: number[] = [];
  for (let i = 0; i < x.length; i++) {
    for (let j = i; j < x.length; j++) w.push((x[i]! + x[j]!) / 2);
  }
  return w.sort((a, b) => a - b);
}

export function wilcoxon(
  differences: readonly number[],
  convention: TieConvention = 'pratt',
): WilcoxonResult | null {
  const tieCount = differences.filter((d) => d === 0).length;
  const used = convention === 'escludi' ? differences.filter((d) => d !== 0) : [...differences];
  if (used.length === 0) return null;

  const ranks = averageRanks(used.map(Math.abs));
  const hasTiedRanks = new Set(used.map(Math.abs)).size !== used.length;

  let wPositive = 0;
  let wNegative = 0;
  for (let i = 0; i < used.length; i++) {
    if (used[i]! > 0) wPositive += ranks[i]!;
    else if (used[i]! < 0) wNegative += ranks[i]!;
  }

  // Under Pratt the zero differences take the lowest ranks and stay out of the
  // statistic for good, but their ranks are not available to the others: that
  // is what makes the distribution different.
  const activeRanks: number[] = [];
  for (let i = 0; i < used.length; i++) if (used[i]! !== 0) activeRanks.push(ranks[i]!);
  const n = activeRanks.length;
  if (n < 1) return null;

  const distribution = nullDistribution(activeRanks);
  const total = Math.pow(2, n);
  const observed = Math.round(Math.min(wPositive, wNegative) * 2);

  let tail = 0;
  for (const [sum, weight] of distribution) if (sum <= observed) tail += weight;
  tail /= total;

  let oneSided: number;
  if (wPositive >= wNegative) {
    const target = Math.round(wPositive * 2);
    let upper = 0;
    for (const [sum, weight] of distribution) if (sum >= target) upper += weight;
    oneSided = upper / total;
  } else {
    oneSided = tail;
  }

  const walsh = walshAverages(convention === 'escludi' ? used.filter((d) => d !== 0) : used);
  return {
    wPositive,
    wNegative,
    pairsUsed: n,
    ties: tieCount,
    convention,
    hasTiedRanks,
    pOneSided: oneSided,
    pTwoSided: Math.min(1, 2 * tail),
    pFloor: Math.min(1, Math.pow(2, 1 - n)),
    hodgesLehmann: medianOf(walsh),
    interval: hodgesLehmannInterval(walsh, distribution, n),
  };
}

function medianOf(x: readonly number[]): number | null {
  if (x.length === 0) return null;
  const s = [...x].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[m]! : (s[m - 1]! + s[m]!) / 2;
}

export function hodgesLehmannInterval(
  walsh: readonly number[],
  distribution: ReadonlyMap<number, number>,
  n: number,
  target = 0.95,
): { low: number; high: number; confidence: number } | null {
  if (walsh.length < 2 || n < 2) return null;
  const total = Math.pow(2, n);
  const values = [...distribution.keys()].sort((a, b) => a - b);
  let cumulative = 0;
  let chosen = -1;
  let confidence = 1;
  for (const v of values) {
    const next = cumulative + (distribution.get(v) ?? 0);
    if (2 * (next / total) > 1 - target) break;
    cumulative = next;
    chosen = Math.round(v / 2);
    confidence = 1 - 2 * (cumulative / total);
  }
  if (chosen < 0) return null;
  const index = chosen;
  if (index >= walsh.length - index) return null;
  return { low: walsh[index]!, high: walsh[walsh.length - 1 - index]!, confidence };
}

// -------------------------------------------------------------------- power

/**
 * Power of a paired comparison that demands unanimity.
 *
 * This is the number to show BEFORE starting, and it is almost always
 * depressing: with six blocks and a two-sided test you need six agreements out
 * of six, so power is simply p^6. Even for a food that genuinely makes things
 * worse in eight blocks out of ten, the chance of reaching a significant result
 * is about 26%.
 */
export function signTestPower(
  blocks: number,
  agreementProbability: number,
  alpha = 0.05,
  oneSided = false,
): number | null {
  if (blocks < 1 || !(agreementProbability > 0) || agreementProbability > 1) return null;
  let needed: number | null = null;
  for (let k = blocks; k > Math.floor(blocks / 2); k--) {
    let tail = 0;
    for (let i = k; i <= blocks; i++) tail += binomialCoefficient(blocks, i);
    tail /= Math.pow(2, blocks);
    const value = oneSided ? tail : Math.min(1, 2 * tail);
    if (value <= alpha) needed = k;
    else break;
  }
  if (needed === null) return 0;
  let power = 0;
  for (let k = needed; k <= blocks; k++) {
    power +=
      binomialCoefficient(blocks, k) *
      Math.pow(agreementProbability, k) *
      Math.pow(1 - agreementProbability, blocks - k);
  }
  return power;
}

/** The fewest blocks that make significance reachable at all. */
export function minimumBlocks(alpha = 0.05, oneSided = false): number {
  for (let n = 1; n <= 40; n++) {
    const tail = 1 / Math.pow(2, n);
    if ((oneSided ? tail : 2 * tail) <= alpha) return n;
  }
  return 40;
}
