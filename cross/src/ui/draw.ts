/**
 * The seven drawings of the form scale, and the small charts.
 *
 * The drawings are the same vectors the Apple app paints, ported to SVG. They
 * are deliberately original: the illustrations of the best known clinical scale
 * are protected works with a disputed owner, and reproducing them would have
 * tied the app to a permission nobody has. The physical ordering, compact to
 * liquid, is not a work.
 */

import { svg } from './dom.js';
import { formZone, type StoolForm } from '../core/model.js';

const FILL: Record<string, string> = {
  compatta: '#9e7047',
  centrale: '#7a5c3d',
  molle: '#8c734d',
};

export function stoolDrawing(form: StoolForm, width = 88, height = 34): SVGElement {
  const colour = FILL[formZone(form)]!;
  const root = svg('svg', {
    viewBox: `0 0 ${width} ${height}`,
    width,
    height,
    'aria-hidden': 'true',
    class: 'form-drawing',
  });
  const cy = height / 2;

  const add = (tag: string, attrs: Record<string, string | number>) =>
    root.appendChild(svg(tag, { fill: colour, ...attrs }));

  switch (form) {
    case 1: {
      const n = 5;
      const r = Math.min(height * 0.22, width / (n * 3));
      const step = width / (n + 1);
      for (let i = 1; i <= n; i++) {
        add('circle', { cx: step * i, cy: cy + (i % 2 === 0 ? -1 : 1) * height * 0.06, r });
      }
      break;
    }
    case 2: {
      const radii = [0.3, 0.36, 0.31, 0.37, 0.29];
      const span = width * 0.86;
      const x0 = (width - span) / 2;
      radii.forEach((k, i) => {
        add('circle', { cx: x0 + (span * i) / (radii.length - 1), cy, r: height * k });
      });
      break;
    }
    case 3: {
      const h = height * 0.56;
      add('rect', { x: width * 0.07, y: cy - h / 2, width: width * 0.86, height: h, rx: h / 2 });
      let d = '';
      for (let i = 1; i <= 4; i++) {
        const x = width * 0.07 + (width * 0.86 * i) / 5;
        d += `M ${x} ${cy - h / 2 + height * 0.08} L ${x - width * 0.015} ${cy + h / 2 - height * 0.08} `;
      }
      root.appendChild(
        svg('path', { d, stroke: 'rgba(255,255,255,0.55)', 'stroke-width': Math.max(1, height * 0.045), fill: 'none' }),
      );
      break;
    }
    case 4: {
      const h = height * 0.52;
      add('rect', { x: width * 0.05, y: cy - h / 2, width: width * 0.9, height: h, rx: h / 2 });
      break;
    }
    case 5: {
      const n = 3;
      const w = width * 0.24;
      const step = width / (n + 1);
      for (let i = 1; i <= n; i++) {
        const h = height * (i === 2 ? 0.46 : 0.4);
        add('rect', { x: step * i - w / 2, y: cy - h / 2, width: w, height: h, rx: h * 0.45 });
      }
      break;
    }
    case 6: {
      const steps = 40;
      const points: string[] = [];
      for (let i = 0; i < steps; i++) {
        const wobble = 1 + 0.13 * Math.sin(i * 1.7) + 0.08 * Math.sin(i * 3.1 + 0.9);
        const a = ((i / steps) * Math.PI * 2);
        points.push(
          `${width / 2 + Math.cos(a) * width * 0.42 * wobble},${cy + Math.sin(a) * height * 0.3 * wobble}`,
        );
      }
      add('polygon', { points: points.join(' ') });
      break;
    }
    case 7: {
      const waves = 4;
      let d = `M ${width * 0.03} ${cy}`;
      for (let i = 0; i < waves; i++) {
        const x0 = width * 0.03 + (width * 0.94 * i) / waves;
        const x1 = width * 0.03 + (width * 0.94 * (i + 1)) / waves;
        d += ` Q ${(x0 + x1) / 2} ${cy + (i % 2 === 0 ? -height * 0.16 : height * 0.16)} ${x1} ${cy}`;
      }
      d += ` L ${width * 0.97} ${cy + height * 0.2} L ${width * 0.03} ${cy + height * 0.2} Z`;
      root.appendChild(svg('path', { d, fill: colour, 'fill-opacity': 0.75 }));
      root.appendChild(
        svg('ellipse', {
          cx: width / 2,
          cy,
          rx: width * 0.4,
          ry: height * 0.24,
          fill: 'none',
          stroke: colour,
          'stroke-opacity': 0.35,
          'stroke-dasharray': `${height * 0.1} ${height * 0.09}`,
          'stroke-width': Math.max(1, height * 0.04),
        }),
      );
      break;
    }
  }
  return root;
}

// ------------------------------------------------------------------ charts

export interface BarDatum {
  label: string;
  value: number;
  highlight?: boolean;
}

/** Horizontal bars with the value written at the end. Reads without colour. */
export function barChart(data: readonly BarDatum[], options: { width?: number; rowHeight?: number } = {}) {
  const width = options.width ?? 320;
  const rowHeight = options.rowHeight ?? 22;
  const labelWidth = 104;
  const valueWidth = 34;
  const plot = width - labelWidth - valueWidth;
  const max = Math.max(1, ...data.map((d) => d.value));
  const root = svg('svg', {
    viewBox: `0 0 ${width} ${rowHeight * data.length}`,
    class: 'chart',
    role: 'img',
  });
  data.forEach((d, i) => {
    const y = i * rowHeight;
    root.appendChild(
      svg('text', { x: labelWidth - 6, y: y + rowHeight / 2 + 4, 'text-anchor': 'end', class: 'chart-label' },
        document.createTextNode(d.label)),
    );
    root.appendChild(
      svg('rect', {
        x: labelWidth,
        y: y + rowHeight * 0.2,
        width: Math.max(1, (plot * d.value) / max),
        height: rowHeight * 0.6,
        rx: 2,
        class: d.highlight ? 'bar bar-strong' : 'bar',
      }),
    );
    root.appendChild(
      svg('text', { x: labelWidth + plot + 6, y: y + rowHeight / 2 + 4, class: 'chart-value' },
        document.createTextNode(String(d.value))),
    );
  });
  return root;
}

/** A line over days, with the mean drawn as a dashed rule. */
export function lineChart(values: readonly { day: string; value: number }[], min: number, max: number) {
  const width = 320;
  const height = 110;
  const pad = 4;
  const root = svg('svg', { viewBox: `0 0 ${width} ${height}`, class: 'chart', role: 'img' });
  if (values.length === 0) return root;
  const x = (i: number) =>
    pad + (i * (width - pad * 2)) / Math.max(1, values.length - 1);
  const y = (v: number) =>
    height - pad - ((v - min) / Math.max(1e-9, max - min)) * (height - pad * 2);

  const mean = values.reduce((a, c) => a + c.value, 0) / values.length;
  root.appendChild(
    svg('line', {
      x1: pad, x2: width - pad, y1: y(mean), y2: y(mean),
      class: 'rule', 'stroke-dasharray': '4 3',
    }),
  );
  root.appendChild(
    svg('polyline', {
      points: values.map((v, i) => `${x(i)},${y(v.value)}`).join(' '),
      class: 'line', fill: 'none',
    }),
  );
  values.forEach((v, i) => root.appendChild(svg('circle', { cx: x(i), cy: y(v.value), r: 2, class: 'dot' })));
  return root;
}

/** Coverage: one bar per day, full height when the day is complete. */
export function coverageChart(days: readonly { day: string; fraction: number; complete: boolean }[]) {
  const width = 320;
  const height = 60;
  const root = svg('svg', { viewBox: `0 0 ${width} ${height}`, class: 'chart', role: 'img' });
  const shown = days.slice(-42);
  const w = Math.max(1, width / Math.max(1, shown.length) - 1);
  shown.forEach((d, i) => {
    const h = Math.max(1, d.fraction * height);
    root.appendChild(
      svg('rect', {
        x: (i * width) / shown.length,
        y: height - h,
        width: w,
        height: h,
        class: d.complete ? 'bar bar-strong' : 'bar bar-partial',
      }),
    );
  });
  return root;
}
