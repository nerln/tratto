/**
 * The domain. Same shapes as the Apple app, same identifiers, same JSON, so a
 * file exported on one platform opens on the other.
 */

// ------------------------------------------------------------- stool form

/**
 * A local seven-level ordinal scale for stool form.
 *
 * Local rather than a known scale for a plain reason: the most widely used
 * seven-level clinical scale is under copyright, and its ownership is disputed
 * between more than one party. The labels here are written from scratch, the
 * drawings are our own vectors, and the name of no proprietary instrument
 * appears in the interface. The 1-7 ordering, from most compact to liquid, is
 * an obvious physical description rather than a work, and it is what keeps the
 * data readable by a clinician and mappable on export.
 */
export const STOOL_FORMS = [1, 2, 3, 4, 5, 6, 7] as const;
export type StoolForm = (typeof STOOL_FORMS)[number];

export const STOOL_FORM_LABEL: Record<StoolForm, string> = {
  1: 'Hard pellets',
  2: 'Lumpy',
  3: 'Cracked',
  4: 'Smooth',
  5: 'Soft pieces',
  6: 'Mushy',
  7: 'Liquid',
};

export const STOOL_FORM_DESCRIPTION: Record<StoolForm, string> = {
  1: 'Separate hard pellets, hard to pass',
  2: 'One compact piece with a lumpy surface',
  3: 'One long piece with cracks on the surface',
  4: 'One long piece, smooth and soft',
  5: 'Soft pieces with clear-cut edges',
  6: 'Ragged pieces, mushy texture',
  7: 'Liquid, with no solid pieces',
};

export type FormZone = 'compatta' | 'centrale' | 'molle';

export function formZone(f: StoolForm): FormZone {
  if (f <= 2) return 'compatta';
  if (f <= 5) return 'centrale';
  return 'molle';
}

/** Outside the middle range. Feeds the binary secondary outcome. */
export function isAbnormal(f: StoolForm): boolean {
  return formZone(f) !== 'centrale';
}

// ----------------------------------------------------------------- day slots

export const SLOTS = [
  'colazione',
  'spuntinoMattina',
  'pranzo',
  'merenda',
  'cena',
  'spuntinoSera',
] as const;
export type Slot = (typeof SLOTS)[number];

export const SLOT_LABEL: Record<Slot, string> = {
  colazione: 'Breakfast',
  spuntinoMattina: 'Morning snack',
  pranzo: 'Lunch',
  merenda: 'Afternoon snack',
  cena: 'Dinner',
  spuntinoSera: 'Evening snack',
};

export const SLOT_HOUR: Record<Slot, number> = {
  colazione: 8,
  spuntinoMattina: 11,
  pranzo: 13,
  merenda: 17,
  cena: 20,
  spuntinoSera: 22,
};

/**
 * The slots a complete day is expected to answer for. Snacks are not expected:
 * in the 2020 diary the morning snack appears once in 59 days, and demanding it
 * would produce a coverage figure that is always low and therefore useless.
 */
export const EXPECTED_SLOTS: readonly Slot[] = ['colazione', 'pranzo', 'cena'];

export function slotFromHour(hour: number): Slot {
  if (hour >= 5 && hour < 10) return 'colazione';
  if (hour >= 10 && hour < 12) return 'spuntinoMattina';
  if (hour >= 12 && hour < 15) return 'pranzo';
  if (hour >= 15 && hour < 18) return 'merenda';
  if (hour >= 18 && hour < 22) return 'cena';
  return 'spuntinoSera';
}

// ------------------------------------------------------------------- records

export type MealState = 'registrato' | 'digiuno' | 'nonRicordato';
export type Amount = 'poca' | 'normale' | 'tanta';

export interface Ingredient {
  id: string;
  nameEn: string;
  nameIt: string;
  categoryEn: string;
  categoryIt: string;
  groups: string[];
  synonyms: string[];
  legacyTerms: string[];
  exposures2020: number;
  userCreated?: boolean;
}

export interface MealItem {
  ingredientId: string;
  amount: Amount;
  sourceText: string;
}

export interface Meal {
  id: string;
  /** ISO 8601 with offset. */
  at: string;
  slot: Slot;
  state: MealState;
  rawText: string;
  items: MealItem[];
  note?: string;
}

export interface BowelEvent {
  id: string;
  at: string;
  form: StoolForm;
  urgency?: number | null;
  pain?: number | null;
  blood: boolean;
  note?: string;
}

export interface DailyOutcome {
  /** yyyy-mm-dd */
  day: string;
  worstPain?: number | null;
  bloating?: number | null;
}

export interface DailyContext {
  day: string;
  sleepHours?: number | null;
  stress?: number | null;
  coffees?: number | null;
  alcohol?: boolean | null;
  exercise?: boolean | null;
  unusualDay?: boolean;
  note?: string;
}

export interface Diary {
  version: number;
  events: BowelEvent[];
  meals: Meal[];
  outcomes: DailyOutcome[];
  contexts: DailyContext[];
  ingredients: Ingredient[];
  comparisons: Comparison[];
}

// --------------------------------------------------------------- comparisons

export type ComparisonOutcome = 'dolore' | 'giornateAnormali';
export type HypothesisDirection = 'bilaterale' | 'unilateraleAumento';
export type BlockCondition = 'bersaglio' | 'controllo';

export interface ComparisonBlock {
  index: number;
  condition: BlockCondition;
  from: string;
  to: string;
  closed: boolean;
}

export interface Comparison {
  id: string;
  targetId: string;
  targetName: string;
  controlId: string;
  controlName: string;
  outcome: ComparisonOutcome;
  direction: HypothesisDirection;
  tieConvention: 'escludi' | 'pratt';
  plannedPairs: number;
  daysPerBlock: number;
  gapDays: number;
  daysDroppedAtStart: number;
  startedOn?: string;
  frozenAt?: string;
  /** SHA-256 of the canonical protocol. */
  fingerprint?: string;
  randomSeed: string;
  blocks: ComparisonBlock[];
  closed: boolean;
  note?: string;
}

/**
 * The canonical text the fingerprint is computed from. It must contain
 * everything that, if it changed later, would make the analysis no longer the
 * one that was declared; and nothing else, or the fingerprint would change for
 * irrelevant reasons.
 */
export function canonicalProtocol(c: Comparison): string {
  return [
    `bersaglio=${c.targetId}`,
    `controllo=${c.controlId}`,
    `esito=${c.outcome}`,
    `direzione=${c.direction}`,
    `pareggi=${c.tieConvention}`,
    `blocchi=${c.plannedPairs}`,
    `giorniPerBlocco=${c.daysPerBlock}`,
    `giorniDiPausa=${c.gapDays}`,
    `giorniScartatiInTesta=${c.daysDroppedAtStart}`,
    `seme=${c.randomSeed}`,
    `sequenza=` +
      [...c.blocks]
        .sort((a, b) => a.index - b.index)
        .map((b) => `${b.index}:${b.condition}`)
        .join(','),
  ].join('\n');
}

// -------------------------------------------------------------- observations

/**
 * The concepts the app knows how to observe, and how they are coded.
 *
 * The coding of this domain is asymmetric, and verified as such: stool form has
 * a SNOMED CT concept but no LOINC code at all (the only "Bristol" in LOINC is
 * a cigarette brand), while a 0-10 pain scale has a LOINC code and needs no
 * SNOMED. SNOMED CT is not free in Italy, so the external codings are optional
 * and off by default while a local coding is always present.
 */
export const LOCAL_CODE_SYSTEM = 'https://nerln.dev/tratto/CodeSystem/osservazioni';
export const SNOMED = 'http://snomed.info/sct';
export const LOINC = 'http://loinc.org';

export interface Coding {
  system: string;
  code: string;
  display: string;
}

export interface Concept {
  id: string;
  label: string;
  external: Coding[];
  clinicianNote?: string;
}

export const CONCEPTS: Record<string, Concept> = {
  formaFecale: {
    id: 'formaFecale',
    label: 'Stool form (local 1-7 scale)',
    external: [{ system: SNOMED, code: '443172007', display: 'Bristol stool form score' }],
    clinicianNote:
      'A 7-level ordinal scale with its own labels and illustrations, ordered from the most compact form (1) to liquid (7). It is not the Bristol scale and the values must not be read as such.',
  },
  frequenzaEvacuazioni: {
    id: 'frequenzaEvacuazioni',
    label: 'Bowel movements per day',
    external: [{ system: SNOMED, code: '249521002', display: 'Frequency of bowel action' }],
  },
  dolorePeggiore24h: {
    id: 'dolorePeggiore24h',
    label: 'Worst abdominal pain in the last 24 hours (0-10)',
    external: [
      {
        system: LOINC,
        code: '72514-3',
        display: 'Pain severity - 0-10 verbal numeric rating [Score] - Reported',
      },
    ],
    clinicianNote: 'Self-reported 0-10 numeric scale, recorded once a day.',
  },
  urgenza: { id: 'urgenza', label: 'Perceived urgency (0-10)', external: [] },
  gonfiore: { id: 'gonfiore', label: 'Perceived bloating (0-10)', external: [] },
  giornoAnormale: {
    id: 'giornoAnormale',
    label: 'Day with at least one bowel movement outside the middle range',
    external: [],
  },
};

export function codingsFor(concept: Concept, includeExternal: boolean): Coding[] {
  const local: Coding = { system: LOCAL_CODE_SYSTEM, code: concept.id, display: concept.label };
  return includeExternal ? [local, ...concept.external] : [local];
}

export function emptyDiary(): Diary {
  return {
    version: 2,
    events: [],
    meals: [],
    outcomes: [],
    contexts: [],
    ingredients: [],
    comparisons: [],
  };
}
