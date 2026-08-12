/**
 * Descriptive statistics and exact paired tests.
 *
 * This is a second implementation of the same maths that the Apple app runs in
 * Swift. Two implementations of the same statistics are an excellent way to
 * drift apart in silence, so neither of them is trusted on its own: Swift
 * writes `fixtures/golden.json` and the test suite here has to reproduce it
 * digit for digit.
 *
 * There is no hypothesis test that relates a food to a symptom anywhere in this
 * file, and there will not be. What is here answers one question the 2020
 * project never asked: how much noise is there, and therefore how large would
 * an effect have to be before it could be seen at all.
 */

// ---------------------------------------------------------------- descriptive

export function mean(x: readonly number[]): number | null {
  if (x.length === 0) return null;
  let s = 0;
  for (const v of x) s += v;
  return s / x.length;
}

export function median(x: readonly number[]): number | null {
  if (x.length === 0) return null;
  const s = [...x].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[m]! : (s[m - 1]! + s[m]!) / 2;
}

/** Sample standard deviation, denominator n-1. */
export function standardDeviation(x: readonly number[]): number | null {
  if (x.length < 2) return null;
  const m = mean(x)!;
  let ss = 0;
  for (const v of x) ss += (v - m) * (v - m);
  return Math.sqrt(ss / (x.length - 1));
}

export function percentile(x: readonly number[], p: number): number | null {
  if (x.length === 0) return null;
  const s = [...x].sort((a, b) => a - b);
  if (s.length === 1) return s[0]!;
  const pos = p * (s.length - 1);
  const lo = Math.floor(pos);
  const hi = Math.min(lo + 1, s.length - 1);
  const f = pos - lo;
  return s[lo]! * (1 - f) + s[hi]! * f;
}

/**
 * Normalised entropy of an ordinal variable: 1 means the levels are used
 * evenly, 0 means it is always the same value. A variable squeezed onto a
 * couple of levels has no room to show an effect, whatever the design.
 */
export function normalisedEntropy(x: readonly number[]): number | null {
  if (x.length === 0) return null;
  const counts = new Map<number, number>();
  for (const v of x) counts.set(v, (counts.get(v) ?? 0) + 1);
  if (counts.size <= 1) return 0;
  const n = x.length;
  let h = 0;
  for (const k of counts.values()) {
    const p = k / n;
    h -= p * Math.log2(p);
  }
  return h / Math.log2(counts.size);
}

// ------------------------------------------------------- variance components

export interface VarianceComponents {
  withinDay: number;
  betweenDays: number;
  /**
   * Share of the variance the day accounts for (one-way random-effects ICC).
   * Near zero means two bowel movements on the same day differ as much as two
   * different days do, and a daily average is then mostly noise.
   */
  icc: number;
  observations: number;
  days: number;
  meanObservationsPerDay: number;
}

export function varianceComponents(groups: readonly (readonly number[])[]): VarianceComponents | null {
  const g = groups.filter((x) => x.length > 0);
  const k = g.length;
  let n = 0;
  for (const x of g) n += x.length;
  if (k < 2 || n <= k) return null;

  let total = 0;
  for (const x of g) for (const v of x) total += v;
  const grand = total / n;

  let ssBetween = 0;
  let ssWithin = 0;
  for (const x of g) {
    const m = mean(x)!;
    ssBetween += x.length * (m - grand) * (m - grand);
    for (const v of x) ssWithin += (v - m) * (v - m);
  }
  const msBetween = ssBetween / (k - 1);
  const msWithin = ssWithin / (n - k);

  let sumSquares = 0;
  for (const x of g) sumSquares += x.length * x.length;
  const n0 = (n - sumSquares / n) / (k - 1);
  if (n0 <= 0) return null;

  const varBetween = Math.max(0, (msBetween - msWithin) / n0);
  const denom = varBetween + msWithin;
  return {
    withinDay: msWithin,
    betweenDays: varBetween,
    icc: denom > 0 ? varBetween / denom : 0,
    observations: n,
    days: k,
    meanObservationsPerDay: n / k,
  };
}

// ---------------------------------------------------------- autocorrelation

export interface Autocorrelation {
  lag: number;
  r: number | null;
  pairs: number;
}

export function pearson(x: readonly number[], y: readonly number[]): number | null {
  if (x.length !== y.length || x.length < 3) return null;
  const mx = mean(x)!;
  const my = mean(y)!;
  let num = 0;
  let sx = 0;
  let sy = 0;
  for (let i = 0; i < x.length; i++) {
    const a = x[i]! - mx;
    const b = y[i]! - my;
    num += a * b;
    sx += a * a;
    sy += b * b;
  }
  const den = Math.sqrt(sx * sy);
  return den > 0 ? num / den : null;
}

/**
 * How much the series resembles itself `lag` days later.
 *
 * It answers a concrete question: how long a gap has to be before the second
 * condition stops carrying the echo of the first. Missing days are real holes;
 * pairs that touch one are dropped rather than interpolated.
 *
 * `series` is keyed by an ISO date (yyyy-mm-dd), which is what makes the day
 * arithmetic identical on every platform and every timezone.
 */
export function autocorrelation(
  series: ReadonlyMap<string, number>,
  maxLag = 7,
  minPairs = 8,
): Autocorrelation[] {
  if (series.size === 0) return [];
  const keys = [...series.keys()].sort();
  const grid: (number | null)[] = [];
  let day = keys[0]!;
  const last = keys[keys.length - 1]!;
  while (day <= last) {
    grid.push(series.get(day) ?? null);
    day = addDays(day, 1);
  }

  const out: Autocorrelation[] = [];
  for (let lag = 1; lag <= Math.max(1, maxLag); lag++) {
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < Math.max(0, grid.length - lag); i++) {
      const a = grid[i];
      const b = grid[i + lag];
      if (a !== null && a !== undefined && b !== null && b !== undefined) {
        xs.push(a);
        ys.push(b);
      }
    }
    out.push(
      xs.length >= minPairs
        ? { lag, r: pearson(xs, ys), pairs: xs.length }
        : { lag, r: null, pairs: xs.length },
    );
  }
  return out;
}

/**
 * The shortest gap after which the series no longer appreciably remembers
 * itself. A number derived from the data, not a constant picked at a desk.
 */
export function suggestedWashout(acf: readonly Autocorrelation[], threshold = 0.2): number | null {
  for (const a of [...acf].sort((p, q) => p.lag - q.lag)) {
    if (a.r === null) continue;
    if (Math.abs(a.r) < threshold) return a.lag;
  }
  return null;
}

// ----------------------------------------------------------------- ISO dates

/** yyyy-mm-dd arithmetic that does not depend on the local timezone. */
export function addDays(iso: string, days: number): string {
  const [y, m, d] = iso.split('-').map(Number) as [number, number, number];
  const t = Date.UTC(y, m - 1, d) + days * 86_400_000;
  return isoFromUTC(new Date(t));
}

export function isoFromUTC(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(
    d.getUTCDate(),
  ).padStart(2, '0')}`;
}

export function daysBetween(a: string, b: string): number {
  const [ay, am, ad] = a.split('-').map(Number) as [number, number, number];
  const [by, bm, bd] = b.split('-').map(Number) as [number, number, number];
  return Math.round((Date.UTC(by, bm - 1, bd) - Date.UTC(ay, am - 1, ad)) / 86_400_000);
}

// ------------------------------------------------- minimum detectable effect

/** Two-sided 97.5% t quantiles for low degrees of freedom. */
const T_CRITICAL = [
  12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179, 2.16, 2.145,
  2.131, 2.12, 2.11, 2.101, 2.093, 2.086, 2.08, 2.074, 2.069, 2.064, 2.06, 2.056, 2.052, 2.048,
  2.045, 2.042,
];

function tCritical(df: number): number {
  if (df < 1) return 12.706;
  return df <= T_CRITICAL.length ? T_CRITICAL[df - 1]! : 1.96;
}

export interface DetectabilityEstimate {
  periods: number;
  daysPerPeriod: number;
  totalDays: number;
  /** The smallest difference, in scale units, that would have an 80% chance of being seen. */
  minimumDifference: number;
}

/**
 * Assumes the periods are independent of one another, which is the best case.
 * The measured autocorrelation says how true that is, and it is why the gap
 * between periods is derived rather than decided.
 */
export function minimumDetectableDifference(
  dailySD: number,
  periods: number,
  daysPerPeriod: number,
  power = 0.8,
): DetectabilityEstimate | null {
  if (!(dailySD > 0) || periods < 2 || daysPerPeriod < 1) return null;
  const sdPeriod = dailySD / Math.sqrt(daysPerPeriod);
  const sdDifference = sdPeriod * Math.SQRT2;
  const z = normalQuantile(power);
  const t = tCritical(periods - 1);
  return {
    periods,
    daysPerPeriod,
    totalDays: periods * daysPerPeriod * 2,
    minimumDifference: ((t + z) * sdDifference) / Math.sqrt(periods),
  };
}

/** Inverse standard normal, Acklam's approximation. */
export function normalQuantile(p: number): number {
  if (!(p > 0 && p < 1)) return 0;
  const a = [
    -3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2, 1.38357751867269e2,
    -3.066479806614716e1, 2.506628277459239,
  ];
  const b = [
    -5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2, 6.680131188771972e1,
    -1.328068155288572e1,
  ];
  const c = [
    -7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838, -2.549732539343734,
    4.374664141464968, 2.938163982698783,
  ];
  const d = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996, 3.754408661907416];
  const pLow = 0.02425;
  const pHigh = 1 - pLow;
  if (p < pLow) {
    const q = Math.sqrt(-2 * Math.log(p));
    return (
      (((((c[0]! * q + c[1]!) * q + c[2]!) * q + c[3]!) * q + c[4]!) * q + c[5]!) /
      ((((d[0]! * q + d[1]!) * q + d[2]!) * q + d[3]!) * q + 1)
    );
  }
  if (p > pHigh) {
    const q = Math.sqrt(-2 * Math.log(1 - p));
    return (
      -(((((c[0]! * q + c[1]!) * q + c[2]!) * q + c[3]!) * q + c[4]!) * q + c[5]!) /
      ((((d[0]! * q + d[1]!) * q + d[2]!) * q + d[3]!) * q + 1)
    );
  }
  const q = p - 0.5;
  const r = q * q;
  return (
    ((((((a[0]! * r + a[1]!) * r + a[2]!) * r + a[3]!) * r + a[4]!) * r + a[5]!) * q) /
    (((((b[0]! * r + b[1]!) * r + b[2]!) * r + b[3]!) * r + b[4]!) * r + 1)
  );
}
