/**
 * The application: five screens, one state, no framework.
 *
 * It is the same app as the Apple one, screen for screen and boundary for
 * boundary. The core it runs on is checked against the Swift implementation by
 * a shared file of golden numbers, so a p-value computed here and a p-value
 * computed on an iPhone are the same p-value.
 */

import { el, clear, section, pill, note, button, slider0to10, formatTime, formatDate } from './ui/dom.js';
import { stoolDrawing, barChart, lineChart, coverageChart } from './ui/draw.js';
import { t, num, percent, setLanguage, detectLanguage, type Lang } from './core/i18n.js';
import {
  EXPECTED_SLOTS,
  SLOTS,
  SLOT_HOUR,
  SLOT_LABEL,
  STOOL_FORMS,
  STOOL_FORM_DESCRIPTION,
  STOOL_FORM_LABEL,
  canonicalProtocol,
  isAbnormal,
  slotFromHour,
  type Comparison,
  type Diary,
  type Ingredient,
  type Slot,
  type StoolForm,
} from './core/model.js';
import {
  loadDiary,
  saveDiary,
  applySeed,
  downloadFile,
  newId,
  sha256Hex,
  deserialise,
  type SeedFile,
} from './core/storage.js';
import { Matcher, orderBySpecificity, type Match } from './core/matching.js';
import {
  autocorrelation,
  median,
  minimumDetectableDifference,
  standardDeviation,
  suggestedWashout,
  varianceComponents,
  isoFromUTC,
} from './core/stats.js';
import { dailyCoverage, coverageWindow } from './core/coverage.js';
import { feasibility, plan, read, VERDICT_LABEL } from './core/comparison.js';
import { exportAll, PLATFORM_MAPPINGS } from './core/export.js';

type Screen = 'now' | 'day' | 'collected' | 'comparisons' | 'export';

interface State {
  diary: Diary;
  screen: Screen;
  day: string;
  lang: Lang;
  externalCodings: boolean;
}

const DISCLAIMER =
  'Tratto records what you enter and shows counts and summaries of it. It does not link foods to symptoms, and it will not: on the numbers a personal diary produces, such a link could not be told apart from chance. It is not a medical device, it does not diagnose, and it does not replace a clinician.';

/** At least this many days with pain recorded before the noise can be estimated. */
const DAYS_TO_ESTIMATE_NOISE = 21;

let state: State;
let root: HTMLElement;

// ------------------------------------------------------------------- helpers

const today = () => isoFromUTC(new Date());

function ingredientName(i: Ingredient): string {
  return state.lang === 'it' ? i.nameIt : i.nameEn;
}

function matcher(): Matcher {
  return new Matcher(
    orderBySpecificity(
      state.diary.ingredients.map((i) => ({
        id: i.id,
        name: ingredientName(i),
        forms: [i.nameIt, i.nameEn, i.id, ...i.synonyms, ...i.legacyTerms],
      })),
    ),
  );
}

async function persist(): Promise<void> {
  await saveDiary(state.diary);
  render();
}

function eventsOn(day: string) {
  return state.diary.events.filter((e) => e.at.slice(0, 10) === day).sort((a, b) => a.at.localeCompare(b.at));
}

function mealsOn(day: string) {
  return state.diary.meals.filter((m) => m.at.slice(0, 10) === day).sort((a, b) => a.at.localeCompare(b.at));
}

function outcomeOn(day: string) {
  return state.diary.outcomes.find((o) => o.day === day);
}

function answeredSlots(day: string): Set<Slot> {
  const out = new Set<Slot>();
  for (const m of mealsOn(day)) {
    const resolved = m.state !== 'registrato' || m.items.length > 0;
    if (resolved) out.add(m.slot);
  }
  return out;
}

function localISOAt(day: string, hour: number): string {
  const d = new Date(`${day}T00:00:00`);
  d.setHours(hour, 0, 0, 0);
  return d.toISOString();
}

// -------------------------------------------------------------------- dialog

function dialog(title: string, body: HTMLElement, onSave?: () => void): void {
  const overlay = el('div', { class: 'overlay' });
  const close = () => overlay.remove();
  const panel = el(
    'div',
    { class: 'sheet', role: 'dialog' },
    el(
      'header',
      {},
      el('h2', {}, title),
      button(t('Close'), close),
    ),
    body,
  );
  if (onSave) {
    panel.appendChild(
      el(
        'footer',
        {},
        button(t('Cancel'), close),
        button(t('Save'), () => {
          onSave();
          close();
        }, 'primary'),
      ),
    );
  }
  overlay.appendChild(panel);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });
  document.body.appendChild(overlay);
}

// ---------------------------------------------------------------- now screen

function bathroomSheet(): void {
  let form: StoolForm | null = null;
  let urgency: number | null = null;
  let pain: number | null = null;
  let blood = false;
  let notes = '';
  let at = new Date().toISOString().slice(0, 16);

  const strip = el('div', { class: 'form-strip' });
  const buttons: HTMLElement[] = [];
  for (const f of STOOL_FORMS) {
    const b = el(
      'button',
      {
        class: 'form-choice',
        type: 'button',
        onclick: () => {
          form = f;
          buttons.forEach((x, i) => x.classList.toggle('chosen', STOOL_FORMS[i] === f));
        },
      },
      stoolDrawing(f),
      el(
        'span',
        {},
        el('strong', {}, t(STOOL_FORM_LABEL[f])),
        el('small', {}, t(STOOL_FORM_DESCRIPTION[f])),
      ),
    );
    buttons.push(b);
    strip.appendChild(b);
  }

  const bloodWarning = el('p', { class: 'note note-warn', hidden: true },
    t('Blood in your stool is something to show a doctor, even if it happens only once and even if you already have an explanation. Tratto just records it.'));

  const body = el(
    'div',
    { class: 'sheet-body' },
    strip,
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Time')),
      el('input', { type: 'datetime-local', value: at, oninput: (e) => { at = (e.target as HTMLInputElement).value; } })),
    el('p', { class: 'muted' }, t('Optional')),
    slider0to10(t('Urgency'), null, (v) => { urgency = v; }),
    slider0to10(t('Pain at the time'), null, (v) => { pain = v; }),
    el('label', { class: 'check' },
      el('input', { type: 'checkbox', onchange: (e) => {
        blood = (e.target as HTMLInputElement).checked;
        bloodWarning.hidden = !blood;
      } }),
      t('I noticed blood')),
    bloodWarning,
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Notes')),
      el('textarea', { rows: 2, oninput: (e) => { notes = (e.target as HTMLTextAreaElement).value; } })),
  );

  dialog(t('Bathroom'), body, () => {
    if (form === null) return;
    state.diary.events.push({
      id: newId(),
      at: new Date(at).toISOString(),
      form,
      urgency,
      pain,
      blood,
      note: notes,
    });
    void persist();
  });
}

function mealSheet(initialText = ''): void {
  let text = initialText;
  let chosen: Match[] = [];
  let candidates: string[] = [];
  let slot: Slot = slotFromHour(new Date().getHours());
  let at = new Date().toISOString().slice(0, 16);

  const chips = el('div', { class: 'chips' });
  const newOnes = el('div', { class: 'chips' });
  const hint = el('p', { class: 'muted', hidden: true },
    t('The question mark marks entries matched by similarity: check them.'));

  const redraw = () => {
    clear(chips);
    for (const m of chosen) {
      chips.appendChild(
        el('button', { class: 'chip', type: 'button', title: t('Remove'),
          onclick: () => { chosen = chosen.filter((x) => x.id !== m.id); redraw(); } },
          m.name, m.kind === 'approssimata' ? ' ?' : ''),
      );
    }
    hint.hidden = !chosen.some((m) => m.kind === 'approssimata');
    clear(newOnes);
    for (const c of candidates) {
      newOnes.appendChild(
        el('button', { class: 'chip chip-new', type: 'button', onclick: () => {
          const id = `utente_${c}`;
          if (!state.diary.ingredients.some((i) => i.id === id)) {
            const label = c.charAt(0).toUpperCase() + c.slice(1);
            state.diary.ingredients.push({
              id, nameEn: label, nameIt: label,
              categoryEn: 'Added by me', categoryIt: 'Aggiunti da me',
              groups: [], synonyms: [], legacyTerms: [], exposures2020: 0, userCreated: true,
            });
          }
          chosen.push({ id, name: c, sourceText: c, kind: 'esatta' });
          candidates = candidates.filter((x) => x !== c);
          redraw();
        } }, `+ ${c}`),
      );
    }
  };

  const recognise = () => {
    const result = matcher().analyse(text);
    const seen = new Set(chosen.map((c) => c.id));
    for (const m of result.matched) if (!seen.has(m.id)) chosen.push(m);
    candidates = result.unmatched.filter((w) => w.length >= 4);
    slot = slotFromHour(new Date(at).getHours());
    redraw();
  };

  const body = el(
    'div',
    { class: 'sheet-body' },
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('What did you eat?')),
      el('textarea', { rows: 3, value: text,
        oninput: (e) => { text = (e.target as HTMLTextAreaElement).value; } })),
    button(t('Recognise'), recognise, 'primary'),
    el('h3', {}, t('Ingredients')), chips, hint,
    el('h3', {}, t('Not in the catalogue')), newOnes,
    el('p', { class: 'muted' },
      t('Tap to add them to your catalogue. Whatever you skip still stays in the text of the meal.')),
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Meal slot')),
      el('select', { onchange: (e) => { slot = (e.target as HTMLSelectElement).value as Slot; } },
        ...SLOTS.map((s) => el('option', { value: s, selected: s === slot }, t(SLOT_LABEL[s]))))),
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Time')),
      el('input', { type: 'datetime-local', value: at,
        oninput: (e) => { at = (e.target as HTMLInputElement).value; } })),
  );
  if (initialText) recognise();

  dialog(t('Meal'), body, () => {
    state.diary.meals.push({
      id: newId(),
      at: new Date(at).toISOString(),
      slot,
      state: 'registrato',
      rawText: text,
      items: chosen.map((c) => ({ ingredientId: c.id, amount: 'normale', sourceText: c.sourceText })),
    });
    void persist();
  });
}

function eveningSheet(day: string): void {
  const existing = outcomeOn(day);
  const context = state.diary.contexts.find((c) => c.day === day);
  let pain = existing?.worstPain ?? null;
  let bloating = existing?.bloating ?? null;
  let stress = context?.stress ?? null;
  let sleep = context?.sleepHours ?? null;
  let coffees = context?.coffees ?? 0;
  let alcohol = context?.alcohol ?? false;
  let exercise = context?.exercise ?? false;
  let unusual = context?.unusualDay ?? false;

  const body = el(
    'div',
    { class: 'sheet-body' },
    el('h3', {}, t('Worst abdominal pain in the last 24 hours')),
    slider0to10('0 – 10', pain, (v) => { pain = v; }),
    el('p', { class: 'muted' }, t('0 means no pain at all, 10 the worst you can imagine.')),
    el('h3', {}, t('Bloating')),
    slider0to10('0 – 10', bloating, (v) => { bloating = v; }),
    el('h3', {}, t('How the day went')),
    slider0to10(t('Stress'), stress, (v) => { stress = v; }),
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Hours of sleep')),
      el('input', { type: 'number', min: 0, max: 14, step: 0.5, value: sleep ?? '',
        oninput: (e) => { const v = (e.target as HTMLInputElement).value; sleep = v === '' ? null : Number(v); } })),
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, t('Coffees')),
      el('input', { type: 'number', min: 0, max: 10, value: coffees,
        oninput: (e) => { coffees = Number((e.target as HTMLInputElement).value); } })),
    el('label', { class: 'check' },
      el('input', { type: 'checkbox', checked: alcohol,
        onchange: (e) => { alcohol = (e.target as HTMLInputElement).checked; } }), t('I drank alcohol')),
    el('label', { class: 'check' },
      el('input', { type: 'checkbox', checked: exercise,
        onchange: (e) => { exercise = (e.target as HTMLInputElement).checked; } }), t('I exercised')),
    el('label', { class: 'check' },
      el('input', { type: 'checkbox', checked: unusual,
        onchange: (e) => { unusual = (e.target as HTMLInputElement).checked; } }), t('Unusual day')),
    el('p', { class: 'muted' },
      t('These entries are not here to explain your symptoms. They are here to record what else was going on, because in a diary kept by one person sleep, stress and coffee move the numbers as much as food does.')),
  );

  dialog(formatDate(day, state.lang), body, () => {
    const outcomes = state.diary.outcomes.filter((o) => o.day !== day);
    outcomes.push({ day, worstPain: pain, bloating });
    state.diary.outcomes = outcomes;
    const contexts = state.diary.contexts.filter((c) => c.day !== day);
    contexts.push({ day, sleepHours: sleep, stress, coffees, alcohol, exercise, unusualDay: unusual });
    state.diary.contexts = contexts;
    void persist();
  });
}

function nowScreen(): HTMLElement {
  const day = today();
  const events = eventsOn(day);
  const answered = answeredSlots(day);
  const missing = EXPECTED_SLOTS.filter((s) => !answered.has(s));
  const outcome = outcomeOn(day);

  const wrap = el('div', { class: 'screen' });

  wrap.appendChild(
    el('div', { class: 'targets' },
      el('button', { class: 'target target-bathroom', type: 'button', onclick: bathroomSheet },
        t('Bathroom')),
      el('button', { class: 'target target-meal', type: 'button', onclick: () => mealSheet() },
        t('Meal'))),
  );

  wrap.appendChild(
    el('div', { class: 'pills' },
      pill(String(events.length), t(events.length === 1 ? 'event' : 'events')),
      pill(`${answered.size}/${EXPECTED_SLOTS.length}`, t('meals answered')),
      pill(outcome?.worstPain != null ? String(outcome.worstPain) : '—', t('pain'))),
  );

  if (missing.length > 0) {
    const list = el('div', { class: 'open-slots' });
    for (const s of missing) {
      list.appendChild(
        el('div', { class: 'open-slot' },
          el('span', {}, t(SLOT_LABEL[s])),
          button(t('Nothing'), () => {
            state.diary.meals.push({ id: newId(), at: localISOAt(day, SLOT_HOUR[s]), slot: s,
              state: 'digiuno', rawText: '', items: [] });
            void persist();
          }),
          button(t("Can't recall"), () => {
            state.diary.meals.push({ id: newId(), at: localISOAt(day, SLOT_HOUR[s]), slot: s,
              state: 'nonRicordato', rawText: '', items: [] });
            void persist();
          })),
      );
    }
    wrap.appendChild(
      section(t('Still open today'), list,
        note(t('Knowing that you ate nothing is data. A slot left blank is not.'))),
    );
  }

  wrap.appendChild(
    button(outcome?.worstPain == null ? t("Record today's pain") : t("Edit today's pain"),
      () => eveningSheet(day), 'primary'),
  );

  const entries = timelineFor(day);
  if (entries.length > 0) wrap.appendChild(section(t('Today'), ...entries));
  wrap.appendChild(note(DISCLAIMER));
  return wrap;
}

// ---------------------------------------------------------------- day screen

function timelineFor(day: string): HTMLElement[] {
  const byId = new Map(state.diary.ingredients.map((i) => [i.id, i]));
  const rows: { at: string; node: HTMLElement }[] = [];
  for (const e of eventsOn(day)) {
    const form = e.form as StoolForm;
    const details: string[] = [];
    if (e.urgency != null) details.push(`${t('Urgency').toLowerCase()} ${e.urgency}`);
    if (e.pain != null) details.push(`${t('pain')} ${e.pain}`);
    if (e.blood) details.push(state.lang === 'it' ? 'sangue' : 'blood');
    rows.push({
      at: e.at,
      node: el('div', { class: 'entry' },
        el('span', { class: 'entry-time' }, formatTime(e.at, state.lang)),
        stoolDrawing(form, 54, 20),
        el('div', {},
          el('strong', {}, t(STOOL_FORM_LABEL[form])),
          details.length > 0 ? el('small', {}, details.join(' · ')) : null)),
    });
  }
  for (const m of mealsOn(day)) {
    const label =
      m.state === 'registrato'
        ? t(SLOT_LABEL[m.slot])
        : `${t(SLOT_LABEL[m.slot])}: ${m.state === 'digiuno' ? t('Nothing').toLowerCase() : t("Can't recall").toLowerCase()}`;
    const names = m.items.map((i) => byId.get(i.ingredientId)).filter(Boolean).map((i) => ingredientName(i!));
    rows.push({
      at: m.at,
      node: el('div', { class: 'entry' },
        el('span', { class: 'entry-time' }, formatTime(m.at, state.lang)),
        el('span', { class: 'entry-icon' }, m.state === 'registrato' ? '🍽' : '–'),
        el('div', {},
          el('strong', {}, label),
          names.length > 0 ? el('small', {}, names.join(', ')) : m.rawText ? el('small', {}, m.rawText) : null)),
    });
  }
  return rows.sort((a, b) => a.at.localeCompare(b.at)).map((r) => r.node);
}

function dayScreen(): HTMLElement {
  const wrap = el('div', { class: 'screen' });
  wrap.appendChild(
    el('div', { class: 'day-nav' },
      button('‹', () => { state.day = shiftDay(state.day, -1); render(); }),
      el('input', { type: 'date', value: state.day,
        onchange: (e) => { state.day = (e.target as HTMLInputElement).value; render(); } }),
      button('›', () => { state.day = shiftDay(state.day, 1); render(); })),
  );
  const entries = timelineFor(state.day);
  wrap.appendChild(
    entries.length > 0
      ? section(formatDate(state.day, state.lang), ...entries)
      : section(formatDate(state.day, state.lang),
          note(state.lang === 'it' ? 'Nessuna registrazione in questo giorno.' : 'Nothing recorded on this day.')),
  );
  wrap.appendChild(button(t("Edit today's pain"), () => eveningSheet(state.day)));
  return wrap;
}

function shiftDay(day: string, delta: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number];
  return isoFromUTC(new Date(Date.UTC(y, m - 1, d + delta)));
}

// ---------------------------------------------------------- collected screen

function collectedScreen(): HTMLElement {
  const wrap = el('div', { class: 'screen' });
  const d = state.diary;

  const answered = new Map<string, Set<Slot>>();
  for (const m of d.meals) {
    if (m.state === 'registrato' && m.items.length === 0) continue;
    const day = m.at.slice(0, 10);
    if (!answered.has(day)) answered.set(day, new Set());
    answered.get(day)!.add(m.slot);
  }
  const eventsPerDay = new Map<string, number>();
  const formsPerDay = new Map<string, number[]>();
  for (const e of d.events) {
    const day = e.at.slice(0, 10);
    eventsPerDay.set(day, (eventsPerDay.get(day) ?? 0) + 1);
    if (!formsPerDay.has(day)) formsPerDay.set(day, []);
    formsPerDay.get(day)!.push(e.form);
  }
  const daysWithOutcome = new Set(d.outcomes.filter((o) => o.worstPain != null).map((o) => o.day));
  const coverage = dailyCoverage({ answeredSlots: answered, eventsPerDay, daysWithOutcome });

  if (coverage.length === 0) {
    wrap.appendChild(section(t('Coverage'), note(t('Nothing to show yet. Record your first event or your first meal.'))));
    return wrap;
  }

  const window7 = coverageWindow(coverage, 7, today());
  wrap.appendChild(
    section(t('Coverage'),
      el('div', { class: 'pills' },
        pill(String(coverage.filter((c) => c.complete).length), t('complete days')),
        pill(percent(window7.meanFraction), t('last 7 days')),
        pill(String(d.events.length), t('events'))),
      coverageChart(coverage),
      !window7.analysable
        ? note(
            state.lang === 'it'
              ? `Negli ultimi 7 giorni la copertura è ${percent(window7.meanFraction)}. Sotto il 70% un periodo non è analizzabile, perché la maggior parte delle giornate non è osservata ma solo in parte nota.`
              : `Coverage over the last 7 days is ${percent(window7.meanFraction)}. Below 70% a period is not analysable, because most days are not observed but only partly known.`,
            'warn')
        : null),
  );

  if (d.events.length > 0) {
    const distribution = STOOL_FORMS.map((f) => ({
      label: t(STOOL_FORM_LABEL[f]),
      value: d.events.filter((e) => e.form === f).length,
    }));
    const abnormalDays = new Set(d.events.filter((e) => isAbnormal(e.form as StoolForm)).map((e) => e.at.slice(0, 10)));
    wrap.appendChild(
      section(t('Stool form'), barChart(distribution),
        el('p', {}, state.lang === 'it'
          ? `Giornate con almeno un'evacuazione fuori dall'intervallo centrale: ${abnormalDays.size} su ${formsPerDay.size} osservate.`
          : `Days with at least one bowel movement outside the middle range: ${abnormalDays.size} of ${formsPerDay.size} observed.`)),
    );
  }

  const painSeries = d.outcomes
    .filter((o) => o.worstPain != null)
    .sort((a, b) => a.day.localeCompare(b.day))
    .map((o) => ({ day: o.day, value: o.worstPain! }));

  if (painSeries.length > 0) {
    const values = painSeries.map((p) => p.value);
    const sd = standardDeviation(values);
    wrap.appendChild(
      section(t('Pain, day by day'), lineChart(painSeries, 0, 10),
        el('p', {}, state.lang === 'it'
          ? `Mediana ${num(median(values)!)}, oscillazione tipica ±${sd ? num(sd) : '—'} punti su ${values.length} giorni.`
          : `Median ${num(median(values)!)}, typical swing ±${sd ? num(sd) : '—'} points over ${values.length} days.`)),
    );
  }

  // how much the numbers move on their own
  const noise = el('div', {});
  if (painSeries.length < DAYS_TO_ESTIMATE_NOISE) {
    noise.appendChild(note(state.lang === 'it'
      ? `Servono almeno ${DAYS_TO_ESTIMATE_NOISE} giorni con il dolore segnato per stimare quanto oscilla da solo. Finora sono ${painSeries.length}.`
      : `At least ${DAYS_TO_ESTIMATE_NOISE} days with pain recorded are needed to estimate how much it swings by itself. So far there are ${painSeries.length}.`));
  } else {
    const sd = standardDeviation(painSeries.map((p) => p.value))!;
    noise.appendChild(el('p', {}, state.lang === 'it'
      ? `Il tuo dolore cambia di circa ${num(sd)} punti da un giorno all'altro senza che sia successo niente di particolare. Serve saperlo prima di poter dire se qualcosa lo cambia davvero.`
      : `Your pain moves by about ${num(sd)} points from one day to the next with nothing in particular happening. That is worth knowing before you can say whether anything changes it.`));

    const series = new Map(painSeries.map((p) => [p.day, p.value]));
    const acf = autocorrelation(series);
    const washout = suggestedWashout(acf);
    noise.appendChild(barChart(acf.filter((a) => a.r !== null).map((a) => ({
      label: `${a.lag}d`, value: Math.round((a.r ?? 0) * 100) / 100,
    }))));
    noise.appendChild(note(washout !== null
      ? (state.lang === 'it'
          ? `Due giorni distanti ${washout} giorni non si somigliano più in modo apprezzabile. È il numero che una pausa fra due condizioni dovrebbe rispettare.`
          : `Two days ${washout} days apart no longer resemble each other appreciably. That is the number a washout between two conditions would have to respect.`)
      : t('Nearby days still resemble each other too much to be treated as independent observations.')));

    for (const periods of [4, 6, 8]) {
      const estimate = minimumDetectableDifference(sd, periods, 5);
      if (!estimate) continue;
      noise.appendChild(el('p', { class: 'row' },
        el('span', {}, state.lang === 'it' ? `${periods} confronti da 5 giorni` : `${periods} comparisons of 5 days`),
        el('strong', {}, `≥ ${num(estimate.minimumDifference)}`)));
    }
  }

  const components = varianceComponents([...formsPerDay.values()]);
  if (components) {
    noise.appendChild(el('p', {}, state.lang === 'it'
      ? `Della variabilità della forma delle feci, ${percent(components.icc)} sta fra giorni diversi e il resto fra evacuazioni dello stesso giorno.`
      : `Of the variation in stool form, ${percent(components.icc)} sits between different days and the rest between bowel movements on the same day.`));
    noise.appendChild(note(t('When the between-days share is low, a daily average is mostly noise.')));
  }
  wrap.appendChild(section(t('How much the numbers move on their own'), noise));

  // exposures
  const counts = new Map<string, { days: Set<string>; n: number }>();
  for (const m of d.meals) {
    const day = m.at.slice(0, 10);
    for (const it of m.items) {
      if (!counts.has(it.ingredientId)) counts.set(it.ingredientId, { days: new Set(), n: 0 });
      const entry = counts.get(it.ingredientId)!;
      entry.n += 1;
      entry.days.add(day);
    }
  }
  const byId = new Map(d.ingredients.map((i) => [i.id, i]));
  const exposures = [...counts.entries()]
    .map(([id, v]) => ({ label: byId.get(id) ? ingredientName(byId.get(id)!) : id, value: v.n }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 15);
  wrap.appendChild(
    section(t('How often you ate what'),
      exposures.length > 0 ? barChart(exposures) : note(state.lang === 'it' ? 'Ancora nessun pasto registrato.' : 'No meals recorded yet.'),
      note(t('This is a count, not a ranking: none of these entries is put in relation with how you felt.'))),
  );

  wrap.appendChild(note(DISCLAIMER));
  return wrap;
}

// -------------------------------------------------------- comparisons screen

function comparisonsScreen(): HTMLElement {
  const wrap = el('div', { class: 'screen' });
  wrap.appendChild(button(t('Plan a comparison'), newComparisonSheet, 'primary'));

  for (const c of state.diary.comparisons) {
    const reading = readComparison(c);
    wrap.appendChild(
      el('button', { class: 'card card-button', type: 'button', onclick: () => comparisonSheet(c) },
        el('div', { class: 'row' },
          el('strong', {}, `${c.targetName} vs ${c.controlName}`),
          el('span', { class: `badge badge-${reading.verdict}` }, t(VERDICT_LABEL[reading.verdict]))),
        el('div', { class: 'blocks' },
          ...c.blocks.map((b) => el('span', { class: `block block-${b.condition}${b.closed ? ' closed' : ''}` }))),
        el('small', {}, state.lang === 'it'
          ? `${reading.pairs.length} coppie su ${c.plannedPairs} completate`
          : `${reading.pairs.length} of ${c.plannedPairs} pairs complete`)),
    );
  }

  if (state.diary.comparisons.length === 0) {
    wrap.appendChild(
      section(state.lang === 'it' ? 'Perché un confronto programmato' : 'Why a planned comparison',
        el('p', {}, state.lang === 'it'
          ? 'Un diario registra quello che succede. Un confronto fa succedere qualcosa apposta, ed è una prova di natura diversa.'
          : 'A diary records what happens. A comparison makes something happen on purpose, and that is a different kind of evidence.'),
        note(state.lang === 'it'
          ? 'Prima di impegnarti, la schermata successiva ti dice quante probabilità ci sono di trovare qualcosa. Di solito sono meno di quanto ci si aspetti.'
          : 'Before you commit, the next screen tells you how likely this is to find anything. Usually it is less than people expect.')),
    );
  }
  wrap.appendChild(note(DISCLAIMER));
  return wrap;
}

function observationsForComparison() {
  const abnormal = new Map<string, boolean>();
  for (const e of state.diary.events) {
    const day = e.at.slice(0, 10);
    abnormal.set(day, (abnormal.get(day) ?? false) || isAbnormal(e.form as StoolForm));
  }
  const days = new Set<string>([...abnormal.keys(), ...state.diary.outcomes.map((o) => o.day)]);
  return [...days].map((day) => ({
    day,
    pain: state.diary.outcomes.find((o) => o.day === day)?.worstPain ?? null,
    abnormalDay: abnormal.get(day) ?? null,
  }));
}

function readComparison(c: Comparison) {
  return read({
    blocks: c.blocks,
    observations: observationsForComparison(),
    outcome: c.outcome,
    direction: c.direction,
    tieConvention: c.tieConvention,
    daysDroppedAtStart: c.daysDroppedAtStart,
    plannedPairs: c.plannedPairs,
    protocolValid: true,
  });
}

function newComparisonSheet(): void {
  const candidates = [...state.diary.ingredients].sort((a, b) => b.exposures2020 - a.exposures2020);
  let targetId = '';
  let controlId = '';
  let outcome: Comparison['outcome'] = 'dolore';
  let direction: Comparison['direction'] = 'bilaterale';
  let pairs = 6;
  let daysPerBlock = 5;
  let gapDays = 4;
  let confirmed = false;

  const figures = el('div', {});
  const redrawFigures = () => {
    clear(figures);
    const f = feasibility(pairs, daysPerBlock, gapDays, direction === 'unilateraleAumento');
    figures.appendChild(el('p', { class: 'row' }, el('span', {}, t('Total length')), el('strong', {}, `${f.totalDays} ${state.lang === 'it' ? 'giorni' : 'days'}`)));
    figures.appendChild(el('p', { class: 'row' }, el('span', {}, t('Pairs that must agree')), el('strong', {}, `${f.agreementsNeeded}/${f.pairs}`)));
    figures.appendChild(el('p', { class: 'row' }, el('span', {}, t('Smallest p you can reach')), el('strong', {}, num(f.pFloor, 3))));
    if (!f.reachable) {
      figures.appendChild(note(state.lang === 'it'
        ? `Con ${f.pairs} coppie nessun risultato può essere significativo, qualunque cosa succeda.`
        : `With ${f.pairs} pairs no result can be significant, whatever happens.`, 'bad'));
    }
    figures.appendChild(el('h4', {}, t('If the target really did affect you…')));
    for (const [label, value] of [
      [state.lang === 'it' ? '…in 7 coppie su 10' : '…in 7 pairs out of 10', f.power70],
      [state.lang === 'it' ? '…in 8 coppie su 10' : '…in 8 pairs out of 10', f.power80],
      [state.lang === 'it' ? '…in 9 coppie su 10' : '…in 9 pairs out of 10', f.power90],
    ] as [string, number][]) {
      figures.appendChild(el('p', { class: 'row' }, el('span', {}, label),
        el('strong', { class: value < 0.5 ? 'weak' : '' }, percent(value))));
    }
    figures.appendChild(note(t('These are the chances of ending up with a significant result. They are low because a comparison this short needs almost every pair to agree.')));
  };
  redrawFigures();

  const stepper = (label: string, get: () => number, set: (v: number) => void, min: number, max: number) =>
    el('label', { class: 'field' },
      el('span', { class: 'field-label' }, label),
      el('input', { type: 'number', min, max, value: get(),
        oninput: (e) => { set(Number((e.target as HTMLInputElement).value)); redrawFigures(); } }));

  const body = el('div', { class: 'sheet-body' },
    el('h3', {}, t('What to compare')),
    el('label', { class: 'field' }, el('span', { class: 'field-label' }, t('Target')),
      el('select', { onchange: (e) => { targetId = (e.target as HTMLSelectElement).value; } },
        el('option', { value: '' }, '—'),
        ...candidates.map((i) => el('option', { value: i.id }, ingredientName(i))))),
    el('label', { class: 'field' }, el('span', { class: 'field-label' }, t('Compared against')),
      el('select', { onchange: (e) => { controlId = (e.target as HTMLSelectElement).value; } },
        el('option', { value: '' }, '—'),
        ...candidates.map((i) => el('option', { value: i.id }, ingredientName(i))))),
    note(state.lang === 'it'
      ? 'Gli alimenti interi non si possono accecare: saprai quale blocco è quale. L’ingrediente di confronto non è un placebo, è qualcosa che non sospetti, così che l’aspettativa abbia qualcosa contro cui essere misurata.'
      : 'Whole foods cannot be blinded: you will know which block is which. The comparison ingredient is not a placebo, it is something you do not suspect, so that expectation has something to be measured against.'),
    el('h3', {}, t('What counts as the outcome')),
    el('label', { class: 'field' }, el('span', { class: 'field-label' }, t('Outcome')),
      el('select', { onchange: (e) => { outcome = (e.target as HTMLSelectElement).value as Comparison['outcome']; } },
        el('option', { value: 'dolore' }, t('Mean daily pain (0-10)')),
        el('option', { value: 'giornateAnormali' }, t('Share of days outside the middle range')))),
    el('label', { class: 'field' }, el('span', { class: 'field-label' }, t('Hypothesis')),
      el('select', { onchange: (e) => { direction = (e.target as HTMLSelectElement).value as Comparison['direction']; redrawFigures(); } },
        el('option', { value: 'bilaterale' }, t('Any difference (two-sided)')),
        el('option', { value: 'unilateraleAumento' }, t('The target makes it worse (one-sided)')))),
    el('h3', {}, t('Shape of the plan')),
    stepper(state.lang === 'it' ? 'Coppie di blocchi' : 'Pairs of blocks', () => pairs, (v) => { pairs = v; }, 3, 12),
    stepper(state.lang === 'it' ? 'Giorni per blocco' : 'Days per block', () => daysPerBlock, (v) => { daysPerBlock = v; }, 3, 10),
    stepper(state.lang === 'it' ? 'Giorni di pausa' : 'Days of gap', () => gapDays, (v) => { gapDays = v; }, 0, 10),
    note(state.lang === 'it'
      ? 'La tua serie si somiglia ancora a 3 giorni di distanza e smette di farlo a 4. Da lì viene la pausa predefinita, non da un protocollo.'
      : 'Your own series still resembles itself 3 days later and stops doing so at 4. That is where the default gap comes from, not from a protocol.'),
    el('h3', {}, t('What you can hope to see')), figures,
    el('label', { class: 'check' },
      el('input', { type: 'checkbox', onchange: (e) => { confirmed = (e.target as HTMLInputElement).checked; } }),
      t('I have read the numbers above')),
  );

  dialog(t('New comparison'), body, () => {
    if (!targetId || !controlId || targetId === controlId || !confirmed) return;
    const target = state.diary.ingredients.find((i) => i.id === targetId)!;
    const control = state.diary.ingredients.find((i) => i.id === controlId)!;
    const seed = BigInt(Math.floor(Math.random() * 2 ** 52)) * 1000003n + 1n;
    const start = today();
    const comparison: Comparison = {
      id: newId(),
      targetId, targetName: target.nameEn,
      controlId, controlName: control.nameEn,
      outcome, direction, tieConvention: 'pratt',
      plannedPairs: pairs, daysPerBlock, gapDays, daysDroppedAtStart: 1,
      startedOn: start, randomSeed: seed.toString(),
      blocks: plan(pairs, daysPerBlock, gapDays, start, seed).map((b) => ({ ...b, closed: false })),
      closed: false,
    };
    void (async () => {
      comparison.frozenAt = new Date().toISOString();
      comparison.fingerprint = await sha256Hex(canonicalProtocol(comparison));
      state.diary.comparisons.push(comparison);
      await persist();
    })();
  });
}

function comparisonSheet(c: Comparison): void {
  const reading = readComparison(c);
  const body = el('div', { class: 'sheet-body' },
    el('h3', {}, t('The frozen plan')),
    el('p', { class: 'row' }, el('span', {}, t('Target')), el('strong', {}, c.targetName)),
    el('p', { class: 'row' }, el('span', {}, t('Compared against')), el('strong', {}, c.controlName)),
    el('p', { class: 'row' }, el('span', {}, t('Outcome')),
      el('strong', {}, t(c.outcome === 'dolore' ? 'Mean daily pain (0-10)' : 'Share of days outside the middle range'))),
    el('p', { class: 'row' }, el('span', {}, t('Fingerprint')),
      el('code', {}, `${(c.fingerprint ?? '').slice(0, 16)}…`)),
    el('h3', {}, t('Blocks')),
    ...c.blocks.map((b) => el('label', { class: 'check' },
      el('input', { type: 'checkbox', checked: b.closed,
        onchange: (e) => { b.closed = (e.target as HTMLInputElement).checked; void persist(); } }),
      `${t(b.condition === 'bersaglio' ? 'Target' : 'Comparison')} · ${formatDate(b.from, state.lang)} → ${formatDate(b.to, state.lang)}`)),
    el('h3', {}, t('Result')),
    el('p', {}, el('strong', {}, t(VERDICT_LABEL[reading.verdict]))),
  );

  if (reading.wilcoxon) {
    const w = reading.wilcoxon;
    const p = c.direction === 'unilateraleAumento' ? w.pOneSided : w.pTwoSided;
    body.appendChild(el('p', { class: 'row' }, el('span', {}, t('Exact p')), el('strong', {}, num(p, 4))));
    body.appendChild(el('p', { class: 'row' }, el('span', {}, t('Pairs used')), el('strong', {}, String(w.pairsUsed))));
    if (w.ties > 0) body.appendChild(el('p', { class: 'row' }, el('span', {}, t('Ties')), el('strong', {}, String(w.ties))));
    if (w.hodgesLehmann !== null) {
      body.appendChild(el('p', { class: 'row' }, el('span', {}, t('Typical difference')), el('strong', {}, num(w.hodgesLehmann, 2))));
    }
    if (w.interval) {
      body.appendChild(el('p', { class: 'row' }, el('span', {}, t('Interval')),
        el('strong', {}, `${num(w.interval.low, 2)} … ${num(w.interval.high, 2)}`)));
      body.appendChild(note(state.lang === 'it'
        ? `L'intervallo è al ${percent(w.interval.confidence)}, non al 95%: con questo numero di coppie il 95% non è fra i livelli che esistono.`
        : `The interval is at ${percent(w.interval.confidence)}, not at 95%: with this many pairs 95% is not one of the levels that exist.`));
    }
  }
  dialog(`${c.targetName} vs ${c.controlName}`, body);
}

// ------------------------------------------------------------- export screen

function exportScreen(): HTMLElement {
  const wrap = el('div', { class: 'screen' });

  wrap.appendChild(
    section(t('What it produces'),
      el('ul', {},
        el('li', {}, 'tratto-events.csv, tratto-meals.csv, tratto-days.csv'),
        el('li', {}, 'tratto-data.json'),
        el('li', {}, 'tratto-fhir.json')),
      el('label', { class: 'check' },
        el('input', { type: 'checkbox', checked: state.externalCodings,
          onchange: (e) => { state.externalCodings = (e.target as HTMLInputElement).checked; } }),
        t('Add SNOMED CT and LOINC to the export')),
      button(t('Generate the files'), () => {
        for (const f of exportAll(state.diary, { includeExternalCodings: state.externalCodings })) {
          downloadFile(f.name, f.contents, f.mime);
        }
      }, 'primary')),
  );

  const importer = el('input', { type: 'file', accept: '.json', onchange: async (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
      state.diary = deserialise(await file.text());
      await persist();
    } catch (err) {
      alert(String(err instanceof Error ? err.message : err));
    }
  } });
  wrap.appendChild(section(t('Import a file'), importer));

  const table = el('table', { class: 'matrix' },
    el('thead', {}, el('tr', {},
      el('th', {}, ''), el('th', {}, 'Apple Health'), el('th', {}, 'Health Connect'))));
  const tbody = el('tbody', {});
  const mark = (s: string) => (s === 'writable' ? '✓' : s === 'lossy' ? '~' : '✗');
  for (const m of PLATFORM_MAPPINGS) {
    tbody.appendChild(el('tr', {},
      el('td', {}, el('strong', {}, m.what), el('small', {}, m.note)),
      el('td', { class: `cell cell-${m.appleHealth}` }, mark(m.appleHealth)),
      el('td', { class: `cell cell-${m.healthConnect}` }, mark(m.healthConnect))));
  }
  table.appendChild(tbody);
  wrap.appendChild(section(t('What the health platforms can and cannot take'), table));
  wrap.appendChild(note(DISCLAIMER));
  return wrap;
}

// ------------------------------------------------------------------- chrome

const SCREENS: { id: Screen; label: string }[] = [
  { id: 'now', label: 'Now' },
  { id: 'day', label: 'Day' },
  { id: 'collected', label: 'Collected' },
  { id: 'comparisons', label: 'Comparisons' },
  { id: 'export', label: 'Export' },
];

function render(): void {
  clear(root);
  const header = el('header', { class: 'app-header' },
    el('h1', {}, 'Tratto'),
    el('select', { class: 'lang', onchange: (e) => {
      const lang = (e.target as HTMLSelectElement).value as Lang;
      state.lang = lang;
      setLanguage(lang);
      localStorage.setItem('tratto.lang', lang);
      render();
    } },
      el('option', { value: 'en', selected: state.lang === 'en' }, 'English'),
      el('option', { value: 'it', selected: state.lang === 'it' }, 'Italiano')));
  root.appendChild(header);

  const main = el('main', {});
  switch (state.screen) {
    case 'now': main.appendChild(nowScreen()); break;
    case 'day': main.appendChild(dayScreen()); break;
    case 'collected': main.appendChild(collectedScreen()); break;
    case 'comparisons': main.appendChild(comparisonsScreen()); break;
    case 'export': main.appendChild(exportScreen()); break;
  }
  root.appendChild(main);

  const nav = el('nav', { class: 'tabbar' });
  for (const s of SCREENS) {
    nav.appendChild(el('button', {
      class: `tab${state.screen === s.id ? ' active' : ''}`,
      type: 'button',
      onclick: () => { state.screen = s.id; render(); },
    }, t(s.label)));
  }
  root.appendChild(nav);
}

export async function start(mount: HTMLElement, seed: SeedFile): Promise<void> {
  root = mount;
  const stored = (localStorage.getItem('tratto.lang') as Lang | null) ?? detectLanguage();
  setLanguage(stored);
  const diary = applySeed(await loadDiary(), seed);
  state = { diary, screen: 'now', day: today(), lang: stored, externalCodings: false };
  await saveDiary(diary);
  render();
}
