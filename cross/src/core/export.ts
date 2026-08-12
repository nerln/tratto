/**
 * The files you hand over, and what can honestly be exchanged with the health
 * platforms.
 *
 * ## What maps where, and what does not
 *
 * **Apple HealthKit** has no type for a bowel movement and none for stool form,
 * and does not accept custom types. It does have seven category types for
 * gastrointestinal symptoms, all on a four-level severity enum. So a lossy,
 * opt-in projection is possible on iOS: bloating and abdominal cramps carry a
 * severity, and diarrhea or constipation can be flagged from the form. The
 * scale itself cannot go.
 *
 * **Health Connect**, the Android equivalent, is worse: its 42 record types
 * contain nothing for bowel movements, stool form, gastrointestinal symptoms or
 * pain, the set is closed, and there are no custom records. Its FHIR support
 * exists but rejects any Observation that is not laboratory, vital-signs,
 * social-history or pregnancy, which excludes everything this diary records.
 * The useful direction there is the opposite one: read sleep and activity from
 * it to fill in the daily context without asking.
 *
 * So the interoperable artefact is a file, not a platform integration. A FHIR
 * R4 bundle carries the real semantics, every code always accompanied by a local
 * coding because SNOMED CT is not free in Italy and the export has to survive
 * that. CSV is the road to R. The PDF is what a clinician actually reads.
 */

import {
  CONCEPTS,
  codingsFor,
  isAbnormal,
  SLOT_LABEL,
  type Diary,
  type StoolForm,
} from './model.js';
import { isoFromUTC } from './stats.js';

export interface ExportOptions {
  includeExternalCodings: boolean;
}

// -------------------------------------------------------------------- CSV

function csvField(s: string): string {
  if (!/[,"\n]/.test(s)) return s;
  return `"${s.replace(/"/g, '""')}"`;
}

export function eventsCsv(d: Diary): string {
  const rows = ['quando,forma_1_7,urgenza_0_10,dolore_0_10,sangue,note'];
  for (const e of [...d.events].sort((a, b) => a.at.localeCompare(b.at))) {
    rows.push(
      [
        e.at,
        String(e.form),
        e.urgency ?? '',
        e.pain ?? '',
        e.blood ? '1' : '0',
        csvField(e.note ?? ''),
      ].join(','),
    );
  }
  return rows.join('\n') + '\n';
}

/** One row per ingredient, which is the shape whoever analyses it needs. */
export function mealsCsv(d: Diary): string {
  const byId = new Map(d.ingredients.map((i) => [i.id, i]));
  const rows = ['quando,fascia,stato,ingrediente_id,ingrediente,categoria,quantita,testo_grezzo'];
  for (const m of [...d.meals].sort((a, b) => a.at.localeCompare(b.at))) {
    if (m.state !== 'registrato' || m.items.length === 0) {
      rows.push([m.at, SLOT_LABEL[m.slot], m.state, '', '', '', '', csvField(m.rawText)].join(','));
      continue;
    }
    for (const it of m.items) {
      const ing = byId.get(it.ingredientId);
      rows.push(
        [
          m.at,
          SLOT_LABEL[m.slot],
          m.state,
          it.ingredientId,
          csvField(ing?.nameEn ?? ''),
          csvField(ing?.categoryEn ?? ''),
          it.amount,
          csvField(m.rawText),
        ].join(','),
      );
    }
  }
  return rows.join('\n') + '\n';
}

export function daysCsv(d: Diary): string {
  const contexts = new Map(d.contexts.map((c) => [c.day, c]));
  const days = new Set([...d.outcomes.map((o) => o.day), ...d.contexts.map((c) => c.day)]);
  const rows = [
    'giorno,dolore_0_10,gonfiore_0_10,ore_sonno,stress_0_10,caffe,alcol,esercizio,atipica',
  ];
  for (const day of [...days].sort()) {
    const o = d.outcomes.find((x) => x.day === day);
    const c = contexts.get(day);
    rows.push(
      [
        day,
        o?.worstPain ?? '',
        o?.bloating ?? '',
        c?.sleepHours ?? '',
        c?.stress ?? '',
        c?.coffees ?? '',
        c?.alcohol === undefined || c?.alcohol === null ? '' : c.alcohol ? '1' : '0',
        c?.exercise === undefined || c?.exercise === null ? '' : c.exercise ? '1' : '0',
        c?.unusualDay ? '1' : '0',
      ].join(','),
    );
  }
  return rows.join('\n') + '\n';
}

// ------------------------------------------------------------------- FHIR

/**
 * A `collection` bundle with one Observation per event and one per day with a
 * pain score. `Observation.code.coding` is an array from the first version of
 * the schema, with the local coding always present: without that, a licence
 * that never arrives would make an archive that is already full impossible to
 * export.
 */
export function fhirBundle(d: Diary, options: ExportOptions): unknown {
  const codeFor = (id: keyof typeof CONCEPTS) => {
    const concept = CONCEPTS[id]!;
    return {
      coding: codingsFor(concept, options.includeExternalCodings),
      text: concept.label,
    };
  };

  const entries: unknown[] = [];

  for (const e of [...d.events].sort((a, b) => a.at.localeCompare(b.at))) {
    const resource: Record<string, unknown> = {
      resourceType: 'Observation',
      status: 'final',
      category: [
        {
          coding: [
            {
              system: 'http://terminology.hl7.org/CodeSystem/observation-category',
              code: 'survey',
              display: 'Survey',
            },
          ],
        },
      ],
      code: codeFor('formaFecale'),
      effectiveDateTime: e.at,
      valueInteger: e.form,
    };
    const note = CONCEPTS.formaFecale!.clinicianNote;
    if (note) resource.note = [{ text: note }];
    if (e.urgency !== null && e.urgency !== undefined) {
      resource.component = [{ code: codeFor('urgenza'), valueInteger: e.urgency }];
    }
    entries.push({ resource });
  }

  for (const o of [...d.outcomes].sort((a, b) => a.day.localeCompare(b.day))) {
    if (o.worstPain === null || o.worstPain === undefined) continue;
    entries.push({
      resource: {
        resourceType: 'Observation',
        status: 'final',
        code: codeFor('dolorePeggiore24h'),
        effectiveDateTime: o.day,
        valueQuantity: {
          value: o.worstPain,
          system: 'http://unitsofmeasure.org',
          code: '{score}',
        },
      },
    });
  }

  return { resourceType: 'Bundle', type: 'collection', entry: entries };
}

// ------------------------------------------------ what the platforms can take

export type PlatformStatus = 'writable' | 'lossy' | 'unsupported';

export interface PlatformMapping {
  what: string;
  appleHealth: PlatformStatus;
  healthConnect: PlatformStatus;
  note: string;
}

/**
 * The honest table, shown in the app and on the site rather than buried.
 * Every "unsupported" here was verified against the platforms' own type lists,
 * not assumed.
 */
export const PLATFORM_MAPPINGS: readonly PlatformMapping[] = [
  {
    what: 'Bowel movements and stool form',
    appleHealth: 'unsupported',
    healthConnect: 'unsupported',
    note: 'Neither platform has a type for it, and neither accepts custom types. This is the core of the diary, and it stays in the file.',
  },
  {
    what: 'Bloating',
    appleHealth: 'lossy',
    healthConnect: 'unsupported',
    note: 'Apple Health has a bloating category on a four-level severity scale, so a 0-10 score can be projected onto it but not recovered from it.',
  },
  {
    what: 'Abdominal pain',
    appleHealth: 'lossy',
    healthConnect: 'unsupported',
    note: 'Apple Health has abdominal cramps, again as severity rather than a 0-10 score.',
  },
  {
    what: 'Diarrhea and constipation flags',
    appleHealth: 'lossy',
    healthConnect: 'unsupported',
    note: 'Derivable from the form of a day, as presence rather than degree.',
  },
  {
    what: 'Sleep, steps, exercise',
    appleHealth: 'writable',
    healthConnect: 'writable',
    note: 'Read, not written. Both platforms already hold this, and reading it fills in the daily context without asking you twice.',
  },
  {
    what: 'Everything, with its real meaning',
    appleHealth: 'unsupported',
    healthConnect: 'unsupported',
    note: 'Which is why the export is a FHIR R4 bundle plus CSV. Health Connect does accept FHIR, but rejects any Observation that is not laboratory, vital signs, social history or pregnancy, and that excludes all of this.',
  },
];

// -------------------------------------------------------- everything at once

export interface ExportedFile {
  name: string;
  mime: string;
  contents: string;
}

export function exportAll(d: Diary, options: ExportOptions): ExportedFile[] {
  return [
    { name: 'tratto-events.csv', mime: 'text/csv', contents: eventsCsv(d) },
    { name: 'tratto-meals.csv', mime: 'text/csv', contents: mealsCsv(d) },
    { name: 'tratto-days.csv', mime: 'text/csv', contents: daysCsv(d) },
    {
      name: 'tratto-data.json',
      mime: 'application/json',
      contents: JSON.stringify({ ...d, exportedAt: new Date().toISOString() }, null, 1),
    },
    {
      name: 'tratto-fhir.json',
      mime: 'application/fhir+json',
      contents: JSON.stringify(fhirBundle(d, options), null, 1),
    },
  ];
}

// ---------------------------------------------------------------- summaries

export interface ReportNumbers {
  from: string | null;
  to: string | null;
  events: number;
  formDistribution: Record<number, number>;
  abnormalDays: number;
  observedDays: number;
  painDays: number;
  painMedian: number | null;
  painMin: number | null;
  painMax: number | null;
}

export function reportNumbers(d: Diary): ReportNumbers {
  const days = new Set<string>();
  const abnormal = new Set<string>();
  const distribution: Record<number, number> = {};
  for (const e of d.events) {
    const day = e.at.slice(0, 10);
    days.add(day);
    distribution[e.form] = (distribution[e.form] ?? 0) + 1;
    if (isAbnormal(e.form as StoolForm)) abnormal.add(day);
  }
  const pains = d.outcomes
    .map((o) => o.worstPain)
    .filter((p): p is number => p !== null && p !== undefined)
    .sort((a, b) => a - b);
  const allDates = [...d.events.map((e) => e.at.slice(0, 10)), ...d.outcomes.map((o) => o.day)].sort();
  return {
    from: allDates[0] ?? null,
    to: allDates[allDates.length - 1] ?? null,
    events: d.events.length,
    formDistribution: distribution,
    abnormalDays: abnormal.size,
    observedDays: days.size,
    painDays: pains.length,
    painMedian:
      pains.length === 0
        ? null
        : pains.length % 2 === 1
          ? pains[(pains.length - 1) / 2]!
          : (pains[pains.length / 2 - 1]! + pains[pains.length / 2]!) / 2,
    painMin: pains[0] ?? null,
    painMax: pains[pains.length - 1] ?? null,
  };
}

export function todayISO(): string {
  return isoFromUTC(new Date());
}
