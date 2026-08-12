/**
 * Local storage, and the file that moves between machines.
 *
 * There is no account, no server and no automatic sync. The diary lives in
 * IndexedDB on whatever device wrote it, and the way it travels is a file the
 * person exports and imports on purpose. That is the same rule the Apple app
 * follows, and it is not only a privacy choice: the exported file is also the
 * artefact you hand to a clinician, so making it the transport keeps one format
 * doing both jobs.
 */

import { emptyDiary, type Diary, type Ingredient } from './model.js';

const DB_NAME = 'tratto';
const DB_VERSION = 1;
const STORE = 'diary';
const KEY = 'current';

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function loadDiary(): Promise<Diary> {
  try {
    const db = await openDatabase();
    const stored = await new Promise<Diary | undefined>((resolve, reject) => {
      const tx = db.transaction(STORE, 'readonly');
      const req = tx.objectStore(STORE).get(KEY);
      req.onsuccess = () => resolve(req.result as Diary | undefined);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return stored ? migrate(stored) : emptyDiary();
  } catch {
    // A browser with storage blocked should still let you use the app for the
    // length of a session rather than showing an error and nothing else.
    return emptyDiary();
  }
}

export async function saveDiary(diary: Diary): Promise<void> {
  const db = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).put(diary, KEY);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

/**
 * Older files open without complaint. A diary is worth more the longer it runs,
 * so a schema change must never be a reason to start again.
 */
export function migrate(d: Partial<Diary>): Diary {
  const base = emptyDiary();
  return {
    version: base.version,
    events: d.events ?? [],
    meals: d.meals ?? [],
    outcomes: d.outcomes ?? [],
    contexts: d.contexts ?? [],
    ingredients: d.ingredients ?? [],
    comparisons: d.comparisons ?? [],
  };
}

// ------------------------------------------------------------------ the seed

export interface SeedFile {
  versione: number;
  ingredienti: {
    id: string;
    nomeIt: string;
    nomeEn: string;
    categoriaIt: string;
    categoriaEn: string;
    gruppi: string[];
    sinonimi: string[];
    terminiLegacy2020: string[];
    esposizioni2020: number;
  }[];
}

export function ingredientsFromSeed(seed: SeedFile): Ingredient[] {
  return seed.ingredienti.map((v) => ({
    id: v.id,
    nameEn: v.nomeEn,
    nameIt: v.nomeIt,
    categoryEn: v.categoriaEn,
    categoryIt: v.categoriaIt,
    groups: v.gruppi,
    synonyms: v.sinonimi,
    legacyTerms: v.terminiLegacy2020,
    exposures2020: v.esposizioni2020,
  }));
}

/**
 * Fills the catalogue on first run and refreshes it when the bundled file moves
 * ahead, without ever touching entries the person added themselves.
 */
export function applySeed(diary: Diary, seed: SeedFile): Diary {
  const incoming = ingredientsFromSeed(seed);
  const mine = new Map(diary.ingredients.map((i) => [i.id, i]));
  const merged: Ingredient[] = [];
  for (const v of incoming) {
    const existing = mine.get(v.id);
    merged.push(existing?.userCreated ? existing : v);
    mine.delete(v.id);
  }
  for (const leftover of mine.values()) merged.push(leftover);
  return { ...diary, ingredients: merged };
}

// -------------------------------------------------------------- file traffic

export function serialise(diary: Diary): string {
  return JSON.stringify({ ...diary, exportedAt: new Date().toISOString() }, null, 1);
}

export function deserialise(text: string): Diary {
  const parsed = JSON.parse(text) as Partial<Diary>;
  if (!Array.isArray(parsed.events) || !Array.isArray(parsed.meals)) {
    throw new Error('This does not look like a Tratto file: no events and no meals in it.');
  }
  return migrate(parsed);
}

/*
 * Saving a file has to take two different roads, and the reason is not a
 * preference.
 *
 * Capacitor's WebView registers no DownloadListener. Checked in the plugin
 * source: none of the sixty Java files under android/capacitor/src/main/java
 * mentions it. So inside the Android app an <a download> click and a blob URL
 * do nothing at all, without an error and without a file. An export that fails
 * in silence is worse than one that refuses, so on a native build the bytes go
 * through the Filesystem plugin and then into the share sheet, which is the
 * only way the user gets to choose where the file lands.
 *
 * Reading a file back needs none of this: Capacitor does implement
 * onShowFileChooser, so <input type="file"> works natively on both roads.
 */

function onNativeAndroid(): boolean {
  const cap = (globalThis as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor;
  return typeof cap?.isNativePlatform === 'function' && cap.isNativePlatform();
}

function toBase64(contents: string | Uint8Array): string {
  const bytes = typeof contents === 'string' ? new TextEncoder().encode(contents) : contents;
  let binary = '';
  // chunked: spreading a large array into String.fromCharCode blows the stack
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

function saveByAnchor(name: string, contents: string | Uint8Array, mime: string): void {
  const blob =
    typeof contents === 'string'
      ? new Blob([contents], { type: mime })
      : new Blob([contents as BlobPart], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function saveByPlugin(name: string, contents: string | Uint8Array): Promise<void> {
  const [{ Filesystem, Directory }, { Share }] = await Promise.all([
    import('@capacitor/filesystem'),
    import('@capacitor/share'),
  ]);
  // Cache, not Documents: these are handed straight to the share sheet and the
  // copy the user keeps is the one they chose to keep.
  const written = await Filesystem.writeFile({
    path: name,
    data: toBase64(contents),
    directory: Directory.Cache,
  });
  await Share.share({ title: name, url: written.uri });
}

/**
 * Write a file out to wherever the platform lets us. Never throws at the call
 * site on the browser road; on the native road a rejection means the user
 * dismissed the share sheet, which is not an error worth showing.
 */
export function downloadFile(name: string, contents: string | Uint8Array, mime: string): void {
  if (!onNativeAndroid()) {
    saveByAnchor(name, contents, mime);
    return;
  }
  void saveByPlugin(name, contents).catch(() => {
    /* dismissed, or no app to receive it */
  });
}

export function newId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

/** SHA-256 in hex, for freezing a comparison protocol. */
export async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
