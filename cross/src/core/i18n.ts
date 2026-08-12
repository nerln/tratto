/**
 * English is the source language; Italian is a translation.
 *
 * The keys are the English sentences, the same convention the Apple app uses
 * with its string catalogue, so the two stay comparable by eye. A missing
 * translation falls back to the key, which means it shows up as English rather
 * than as a blank or a raw identifier.
 */

export type Lang = 'en' | 'it';

const IT: Record<string, string> = {
  // navigation
  Now: 'Adesso',
  Day: 'Giornata',
  Collected: 'Raccolta',
  Comparisons: 'Confronti',
  Export: 'Esporta',
  Settings: 'Impostazioni',
  '2020 archive': 'Archivio 2020',

  // now
  Bathroom: 'Bagno',
  Meal: 'Pasto',
  events: 'eventi',
  event: 'evento',
  'meals answered': 'fasce risolte',
  pain: 'dolore',
  'Still open today': 'Fasce ancora aperte oggi',
  Nothing: 'Niente',
  "Can't recall": 'Non ricordo',
  'Knowing that you ate nothing is data. A slot left blank is not.':
    'Sapere che non hai mangiato è un dato. Una fascia lasciata vuota, no.',
  "Record today's pain": 'Segna il dolore di oggi',
  "Edit today's pain": 'Modifica il dolore di oggi',
  Today: 'Oggi',

  // slots
  Breakfast: 'Colazione',
  'Morning snack': 'Spuntino del mattino',
  Lunch: 'Pranzo',
  'Afternoon snack': 'Merenda',
  Dinner: 'Cena',
  'Evening snack': 'Spuntino della sera',

  // stool form
  'Hard pellets': 'Palline dure',
  Lumpy: 'Grumosa',
  Cracked: 'Con crepe',
  Smooth: 'Liscia',
  'Soft pieces': 'Pezzi morbidi',
  Mushy: 'Poltiglia',
  Liquid: 'Liquida',
  'Separate hard pellets, hard to pass': 'Palline separate e dure, difficili da espellere',
  'One compact piece with a lumpy surface': 'Un unico pezzo compatto, con la superficie a grumi',
  'One long piece with cracks on the surface': 'Un unico pezzo allungato, con delle crepe sopra',
  'One long piece, smooth and soft': 'Un unico pezzo allungato, liscio e morbido',
  'Soft pieces with clear-cut edges': 'Pezzi morbidi con i bordi ben definiti',
  'Ragged pieces, mushy texture': 'Pezzi sfrangiati, consistenza di poltiglia',
  'Liquid, with no solid pieces': 'Liquida, senza pezzi solidi',

  // entry
  Time: 'Ora',
  Optional: 'Facoltativo',
  Urgency: 'Urgenza',
  'Pain at the time': 'Dolore in quel momento',
  'I noticed blood': 'Ho notato del sangue',
  Notes: 'Note',
  Save: 'Salva',
  Cancel: 'Annulla',
  Close: 'Chiudi',
  Remove: 'Togli',
  'What did you eat?': 'Che cosa hai mangiato?',
  Recognise: 'Riconosci',
  Ingredients: 'Ingredienti',
  'Not in the catalogue': 'Non sono nel catalogo',
  'Tap to add them to your catalogue. Whatever you skip still stays in the text of the meal.':
    'Tocca per aggiungerli al tuo catalogo. Quello che non aggiungi resta comunque scritto nel testo del pasto.',
  'The question mark marks entries matched by similarity: check them.':
    'Il punto interrogativo segna le voci riconosciute per somiglianza: controllale.',
  'Meal slot': 'Fascia',
  'Blood in your stool is something to show a doctor, even if it happens only once and even if you already have an explanation. Tratto just records it.':
    'Il sangue nelle feci è una cosa da far vedere a un medico, anche se succede una volta sola e anche se hai già una spiegazione. Tratto lo annota e basta.',

  // evening
  'Worst abdominal pain in the last 24 hours': 'Il peggior dolore alla pancia nelle ultime 24 ore',
  '0 means no pain at all, 10 the worst you can imagine.':
    '0 vuol dire nessun dolore, 10 il peggiore che riesci a immaginare.',
  Bloating: 'Gonfiore',
  'How the day went': "Com'è andata la giornata",
  Stress: 'Stress',
  'Hours of sleep': 'Ore di sonno',
  Coffees: 'Caffè',
  'I drank alcohol': 'Ho bevuto alcol',
  'I exercised': 'Ho fatto attività fisica',
  'Unusual day': 'Giornata fuori dal solito',
  'These entries are not here to explain your symptoms. They are here to record what else was going on, because in a diary kept by one person sleep, stress and coffee move the numbers as much as food does.':
    'Queste voci non servono a spiegare i sintomi. Servono a sapere che cos’altro stava succedendo, perché in un diario di una persona sola sonno, stress e caffè muovono i numeri quanto il cibo.',
  'not set': 'non indicato',

  // collected
  Coverage: 'Copertura',
  'complete days': 'giorni completi',
  'last 7 days': 'ultimi 7 giorni',
  'Stool form': 'Forma delle feci',
  'Pain, day by day': 'Dolore, giorno per giorno',
  'How much the numbers move on their own': 'Quanto oscillano i numeri da soli',
  'How often you ate what': 'Quante volte hai mangiato che cosa',
  'How large an effect would have to be to show up':
    'Quanto dovrebbe essere grande un effetto per potersi vedere',
  'Nothing to show yet. Record your first event or your first meal.':
    'Non c’è ancora niente da mostrare. Registra il primo evento o il primo pasto.',
  'This is a count, not a ranking: none of these entries is put in relation with how you felt.':
    'È un conteggio, non una classifica: nessuna di queste voci è messa in relazione con come è andata.',
  'When the between-days share is low, a daily average is mostly noise.':
    'Quando la quota fra giorni è bassa, la media di una giornata è per lo più rumore.',
  'Nearby days still resemble each other too much to be treated as independent observations.':
    'I giorni vicini si somigliano ancora troppo perché si possano trattare come osservazioni indipendenti.',

  // comparisons
  'Plan a comparison': 'Programma un confronto',
  'New comparison': 'Nuovo confronto',
  'What to compare': 'Che cosa confrontare',
  Target: 'Bersaglio',
  'Compared against': 'Confrontato con',
  'What counts as the outcome': 'Che cosa conta come esito',
  Outcome: 'Esito',
  Hypothesis: 'Ipotesi',
  'Mean daily pain (0-10)': 'Dolore medio giornaliero (0-10)',
  'Share of days outside the middle range': 'Quota di giornate fuori dall’intervallo centrale',
  'Any difference (two-sided)': 'Una differenza qualsiasi (bilaterale)',
  'The target makes it worse (one-sided)': 'Il bersaglio peggiora le cose (unilaterale)',
  'Shape of the plan': 'Forma del piano',
  'What you can hope to see': 'Che cosa puoi sperare di vedere',
  'Freeze and start': 'Congela e inizia',
  'I have read the numbers above': 'Ho letto i numeri qui sopra',
  'Total length': 'Durata totale',
  'Pairs that must agree': 'Coppie che devono concordare',
  'Smallest p you can reach': 'p più piccolo raggiungibile',
  'If the target really did affect you…': 'Se il bersaglio ti riguardasse davvero…',
  'These are the chances of ending up with a significant result. They are low because a comparison this short needs almost every pair to agree.':
    'Sono le probabilità di arrivare a un risultato significativo. Sono basse perché un confronto così corto ha bisogno che quasi tutte le coppie concordino.',
  'The frozen plan': 'Il piano congelato',
  Fingerprint: 'Impronta',
  Blocks: 'Blocchi',
  Result: 'Risultato',
  'Exact p': 'p esatto',
  'Pairs used': 'Coppie usate',
  Ties: 'Pareggi',
  'Typical difference': 'Differenza tipica',
  Interval: 'Intervallo',
  'Consistent with an effect': 'Coerente con un effetto',
  'No detectable effect': 'Nessun effetto rilevabile',
  Inconclusive: 'Non concludente',
  'Protocol changed after it was frozen': 'Piano cambiato dopo il congelamento',
  'Not finished yet': 'Non ancora finito',
  Comparison: 'Confronto',

  // export
  'What it produces': 'Che cosa produce',
  'Generate the files': 'Genera i file',
  'Import a file': 'Importa un file',
  'Add SNOMED CT and LOINC to the export': 'Aggiungi SNOMED CT e LOINC all’esportazione',
  'What the health platforms can and cannot take':
    'Che cosa le piattaforme di salute possono prendere e che cosa no',

  // settings
  Language: 'Lingua',
  'Follow the system': 'Segui il sistema',
  'What Tratto is for': 'A che cosa serve Tratto',
  'Erase everything': 'Cancella tutto',
};

const DICTIONARIES: Record<Lang, Record<string, string>> = { en: {}, it: IT };

let current: Lang = 'en';

export function setLanguage(lang: Lang): void {
  current = lang;
  if (typeof document !== 'undefined') document.documentElement.lang = lang;
}

export function language(): Lang {
  return current;
}

/** Resolves a key. Unknown keys come back as themselves, which reads as English. */
export function t(key: string): string {
  return DICTIONARIES[current]?.[key] ?? key;
}

/** Formats a number the way the current language writes it. */
export function num(value: number, digits = 1): string {
  return new Intl.NumberFormat(current === 'it' ? 'it-IT' : 'en-GB', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
}

export function percent(fraction: number): string {
  return `${Math.round(fraction * 100)}%`;
}

export function plural(n: number, singular: string, many: string): string {
  return `${n} ${t(n === 1 ? singular : many)}`;
}

export function detectLanguage(): Lang {
  if (typeof navigator === 'undefined') return 'en';
  return navigator.language.toLowerCase().startsWith('it') ? 'it' : 'en';
}
