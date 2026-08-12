/**
 * Recognises ingredients from the closed vocabulary inside a free-text meal.
 *
 * Deterministic on purpose. Measured on the on-device model the Apple app can
 * use: left free to produce strings it invents entries the vocabulary does not
 * contain; constrained to a closed schema it stops inventing but also stops
 * recognising, returning empty lists on two sentences out of three. Neither
 * mode holds on its own. So a model, where one exists, only ever proposes
 * fragments of text; the decision about what counts as an ingredient stays
 * here, in code that can be read and that fails the same way every time.
 */

export interface VocabularyEntry {
  id: string;
  name: string;
  /** Every written form this entry may be recognised under. */
  forms: string[];
}

export type MatchKind = 'esatta' | 'approssimata';

export interface Match {
  id: string;
  name: string;
  sourceText: string;
  kind: MatchKind;
}

export interface MatchResult {
  matched: Match[];
  unmatched: string[];
}

/**
 * Words that are never ingredients, so that "a bit of" does not become a diary
 * entry. Both languages, because the interface language and the language people
 * dictate in are not the same thing.
 */
export const FILLER_WORDS = new Set<string>([
  // italiano
  'di', 'del', 'della', 'dello', 'dei', 'delle', 'degli', 'da', 'dal', 'con', 'e', 'ed',
  'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una', 'al', 'alla', 'allo',
  'ai', 'alle', 'agli', 'in', 'su', 'per', 'po', 'poco', 'poca', 'tanto', 'tanta',
  'molto', 'molta', 'un_po', 'solo', 'anche', 'piu', 'meno', 'stamattina', 'stasera',
  'stanotte', 'oggi', 'ieri', 'pranzo', 'cena', 'colazione', 'merenda', 'spuntino',
  'mangiato', 'bevuto', 'preso', 'fetta', 'fette', 'fettina', 'pezzo', 'pezzi',
  'piatto', 'porzione', 'bicchiere', 'tazza', 'cucchiaio', 'filo', 'grattata',
  'circa', 'quasi', 'tipo', 'come', 'sempre', 'solito', 'solita', 'bianco', 'bianca',
  // english
  'a', 'an', 'the', 'of', 'with', 'and', 'some', 'few', 'little', 'lot', 'lots',
  'bit', 'piece', 'pieces', 'slice', 'slices', 'plate', 'glass', 'cup', 'spoon',
  'drizzle', 'today', 'yesterday', 'tonight', 'morning', 'evening', 'breakfast',
  'lunch', 'dinner', 'snack', 'ate', 'had', 'drank', 'two', 'three', 'four', 'five',
  'for', 'my', 'me', 'i', 'on', 'in', 'at', 'to', 'plain', 'white',
]);

export function normalise(s: string): string {
  const stripped = s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
  return stripped
    .split('')
    .map((c) => (/[a-z0-9]/.test(c) ? c : ' '))
    .join('')
    .split(' ')
    .filter((w) => w.length > 0)
    .join('_');
}

/**
 * Singular and plural variants generated with the plainest Italian rules. Only
 * the last word of a compound form is inflected.
 */
export function inflections(word: string): Set<string> {
  const parts = word.split('_');
  const last = parts[parts.length - 1];
  if (!last || last.length < 4) return new Set();
  const prefix = parts.slice(0, -1).join('_');
  const out = new Set<string>();
  const stem = last.slice(0, -1);
  switch (last[last.length - 1]) {
    case 'o':
      out.add(stem + 'i');
      break;
    case 'a':
      out.add(stem + 'e');
      out.add(stem + 'i');
      break;
    case 'e':
      out.add(stem + 'i');
      out.add(stem + 'a');
      break;
    case 'i':
      out.add(stem + 'o');
      out.add(stem + 'e');
      out.add(stem + 'a');
      break;
    // english plural
    case 's':
      out.add(stem);
      break;
  }
  if (last.endsWith('co')) out.add(last.slice(0, -2) + 'chi');
  if (last.endsWith('ca')) out.add(last.slice(0, -2) + 'che');
  if (last.endsWith('chi')) out.add(last.slice(0, -3) + 'co');
  if (last.endsWith('che')) out.add(last.slice(0, -3) + 'ca');
  if (!last.endsWith('s')) out.add(last + 's');
  return new Set([...out].map((v) => (prefix ? `${prefix}_${v}` : v)));
}

export function keysFor(form: string): Set<string> {
  const base = normalise(form);
  if (!base) return new Set();
  const keys = new Set<string>([base, base.replace(/_/g, '')]);
  for (const v of inflections(base)) keys.add(v);
  return keys;
}

/** Levenshtein distance with early exit. */
export function editDistance(a: string, b: string, limit: number): number {
  if (a === b) return 0;
  if (Math.abs(a.length - b.length) > limit) return limit + 1;
  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  let current = new Array<number>(b.length + 1).fill(0);
  for (let i = 1; i <= a.length; i++) {
    current[0] = i;
    let rowMin = current[0]!;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      current[j] = Math.min(previous[j]! + 1, current[j - 1]! + 1, previous[j - 1]! + cost);
      rowMin = Math.min(rowMin, current[j]!);
    }
    if (rowMin > limit) return limit + 1;
    [previous, current] = [current, previous];
  }
  return previous[b.length]!;
}

export class Matcher {
  private readonly index = new Map<string, VocabularyEntry>();
  private readonly byId = new Map<string, VocabularyEntry>();

  constructor(entries: readonly VocabularyEntry[]) {
    for (const e of entries) {
      this.byId.set(e.id, e);
      for (const form of e.forms) {
        for (const key of keysFor(form)) {
          // The first entry to claim a key keeps it: callers pass entries
          // already ordered by specificity, so "wholewheat pasta" wins over
          // "pasta".
          if (!this.index.has(key)) this.index.set(key, e);
        }
      }
    }
  }

  entry(id: string): VocabularyEntry | undefined {
    return this.byId.get(id);
  }

  /**
   * Walks the text looking for the longest run of words that matches an entry,
   * then falls back to shorter runs.
   */
  analyse(text: string, maxLength = 4, maxDistance = 2): MatchResult {
    const words = normalise(text).split('_').filter(Boolean);
    if (words.length === 0) return { matched: [], unmatched: [] };

    const matched: Match[] = [];
    const seen = new Set<string>();
    const unmatched: string[] = [];
    let i = 0;

    while (i < words.length) {
      let found = false;
      const maximum = Math.min(maxLength, words.length - i);
      for (let length = maximum; length >= 1; length--) {
        const run = words.slice(i, i + length).join('_');
        const hit = this.lookup(run, maxDistance);
        if (hit) {
          if (!seen.has(hit.entry.id)) {
            seen.add(hit.entry.id);
            matched.push({
              id: hit.entry.id,
              name: hit.entry.name,
              sourceText: words.slice(i, i + length).join(' '),
              kind: hit.kind,
            });
          }
          i += length;
          found = true;
          break;
        }
      }
      if (!found) {
        const w = words[i]!;
        if (!FILLER_WORDS.has(w) && w.length >= 3 && !/^\d+$/.test(w)) unmatched.push(w);
        i += 1;
      }
    }
    return { matched, unmatched };
  }

  private lookup(
    run: string,
    maxDistance: number,
  ): { entry: VocabularyEntry; kind: MatchKind } | null {
    if (FILLER_WORDS.has(run)) return null;
    const exact = this.index.get(run);
    if (exact) return { entry: exact, kind: 'esatta' };
    for (const variant of inflections(run)) {
      const v = this.index.get(variant);
      if (v) return { entry: v, kind: 'esatta' };
    }
    // Similarity only on words long enough, or "rice" and "vice" become the
    // same thing.
    if (run.length < 5 || maxDistance <= 0) return null;
    const limit = run.length >= 8 ? maxDistance : 1;
    let best: { entry: VocabularyEntry; distance: number } | null = null;
    for (const [key, entry] of this.index) {
      if (Math.abs(key.length - run.length) > limit) continue;
      const d = editDistance(key, run, limit);
      if (d <= limit && (best === null || d < best.distance)) best = { entry, distance: d };
      if (d === 0) break;
    }
    return best ? { entry: best.entry, kind: 'approssimata' } : null;
  }
}

/** Orders entries so the most specific forms claim their keys first. */
export function orderBySpecificity(entries: readonly VocabularyEntry[]): VocabularyEntry[] {
  return [...entries].sort((a, b) => {
    const la = Math.max(0, ...a.forms.map((f) => f.length));
    const lb = Math.max(0, ...b.forms.map((f) => f.length));
    return lb - la;
  });
}
