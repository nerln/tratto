/**
 * A few hundred bytes instead of a framework.
 *
 * The app has five screens and rebuilds one of them at a time, so nothing here
 * needs a virtual DOM. Keeping it this small is also what lets the same bundle
 * be the web app, the Windows app and the Android app without the download
 * being embarrassing.
 */

type Child = Node | string | null | undefined | false;

export interface Attributes {
  class?: string;
  id?: string;
  type?: string;
  value?: string | number;
  placeholder?: string;
  href?: string;
  title?: string;
  min?: string | number;
  max?: string | number;
  step?: string | number;
  rows?: string | number;
  checked?: boolean;
  disabled?: boolean;
  hidden?: boolean;
  role?: string;
  lang?: string;
  onclick?: (e: MouseEvent) => void;
  oninput?: (e: Event) => void;
  onchange?: (e: Event) => void;
  onsubmit?: (e: Event) => void;
  [key: string]: unknown;
}

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attributes: Attributes = {},
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attributes)) {
    if (value === undefined || value === null || value === false) continue;
    if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2), value as EventListener);
    } else if (key === 'checked' || key === 'disabled' || key === 'hidden') {
      (node as unknown as Record<string, unknown>)[key] = value;
    } else if (key === 'value') {
      (node as HTMLInputElement).value = String(value);
    } else {
      node.setAttribute(key, String(value));
    }
  }
  append(node, children);
  return node;
}

export function append(parent: Node, children: Child[]): void {
  for (const c of children) {
    if (c === null || c === undefined || c === false) continue;
    parent.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
}

export function clear(node: Node): void {
  while (node.firstChild) node.removeChild(node.firstChild);
}

export function svg(tag: string, attributes: Record<string, string | number>, ...children: Node[]) {
  const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
  for (const [k, v] of Object.entries(attributes)) node.setAttribute(k, String(v));
  for (const c of children) node.appendChild(c);
  return node;
}

/** A labelled block, the shape every screen is made of. */
export function section(title: string, ...children: Child[]): HTMLElement {
  return el('section', { class: 'card' }, el('h2', {}, title), ...children);
}

export function pill(value: string, label: string): HTMLElement {
  return el('div', { class: 'pill' }, el('strong', {}, value), el('span', {}, label));
}

export function note(text: string, tone: 'plain' | 'warn' | 'bad' = 'plain'): HTMLElement {
  return el('p', { class: `note note-${tone}` }, text);
}

export function button(
  label: string,
  onclick: () => void,
  variant: 'primary' | 'plain' | 'big' = 'plain',
): HTMLElement {
  return el('button', { class: `btn btn-${variant}`, type: 'button', onclick }, label);
}

/** A 0-10 slider that stays unset until it is touched. */
export function slider0to10(
  label: string,
  initial: number | null,
  onChange: (value: number | null) => void,
): HTMLElement {
  let value = initial;
  const readout = el('span', { class: 'readout' }, value === null ? '' : String(value));
  const input = el('input', {
    type: 'range',
    min: 0,
    max: 10,
    step: 1,
    value: value ?? 0,
    oninput: (e) => {
      value = Number((e.target as HTMLInputElement).value);
      readout.textContent = String(value);
      onChange(value);
    },
  });
  return el(
    'label',
    { class: 'field' },
    el('span', { class: 'field-label' }, label, readout),
    input,
  );
}

export function formatTime(iso: string, lang: string): string {
  const d = new Date(iso);
  return new Intl.DateTimeFormat(lang === 'it' ? 'it-IT' : 'en-GB', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(d);
}

export function formatDate(iso: string, lang: string): string {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number) as [number, number, number];
  return new Intl.DateTimeFormat(lang === 'it' ? 'it-IT' : 'en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(Date.UTC(y, m - 1, d)));
}
