/**
 * The contract with the Swift implementation.
 *
 * `fixtures/golden.json` is written by the Apple app's test suite and read here.
 * Every number in it has to come out the same. If one of the two ever drifts,
 * this file is the thing that says so, and it says so on the very next run
 * rather than in a report that quietly stops matching the other platform.
 */
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  signTest,
  wilcoxon,
  averageRanks,
  signTestPower,
  minimumBlocks,
  binomialCoefficient,
} from '../src/core/exact.js';
import {
  mean,
  median,
  standardDeviation,
  percentile,
  normalisedEntropy,
  varianceComponents,
  autocorrelation,
  minimumDetectableDifference,
  normalQuantile,
} from '../src/core/stats.js';
import { sequence, feasibility } from '../src/core/comparison.js';
import { dailyCoverage, coverageWindow } from '../src/core/coverage.js';
import { Matcher, orderBySpecificity, normalise, editDistance } from '../src/core/matching.js';
import {
  STOOL_FORMS,
  STOOL_FORM_LABEL,
  STOOL_FORM_DESCRIPTION,
  formZone,
  isAbnormal,
  CONCEPTS,
  codingsFor,
  type Slot,
  type StoolForm,
} from '../src/core/model.js';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..');

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const golden: any = JSON.parse(readFileSync(join(repo, 'fixtures', 'golden.json'), 'utf8'));
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const seed: any = JSON.parse(
  readFileSync(join(repo, 'Tratto', 'Resources', 'seed-ontologia.json'), 'utf8'),
);

/** Floating point: the same algorithm on the same doubles, so this is generous. */
const near = (a: number, b: number, eps = 1e-12) => expect(Math.abs(a - b)).toBeLessThan(eps);

describe('golden fixtures exist and are the expected shape', () => {
  it('was produced by Swift', () => {
    expect(golden.prodottoDa).toBe('Tratto (Swift)');
    expect(golden.versione).toBe(2);
  });
});

describe('sign test', () => {
  for (const c of golden.testDeiSegni) {
    it(c.nome, () => {
      const r = signTest(c.valori);
      expect(r).not.toBeNull();
      expect(r!.positive).toBe(c.positivi);
      expect(r!.negative).toBe(c.negativi);
      expect(r!.ties).toBe(c.pareggi);
      expect(r!.pairsUsed).toBe(c.coppieUsate);
      near(r!.pOneSided, c.pUnilaterale);
      near(r!.pTwoSided, c.pBilaterale);
      near(r!.pFloor, c.pMinimoRaggiungibile);
    });
  }
});

describe('wilcoxon signed rank', () => {
  for (const c of golden.wilcoxon) {
    it(`${c.nome} / ${c.convenzione}`, () => {
      const r = wilcoxon(c.valori, c.convenzione);
      expect(r).not.toBeNull();
      near(r!.wPositive, c.wPositivo);
      near(r!.wNegative, c.wNegativo);
      expect(r!.pairsUsed).toBe(c.coppieUsate);
      expect(r!.ties).toBe(c.pareggi);
      expect(r!.hasTiedRanks).toBe(c.ranghiConExAequo);
      near(r!.pOneSided, c.pUnilaterale);
      near(r!.pTwoSided, c.pBilaterale);
      near(r!.pFloor, c.pMinimoRaggiungibile);
      if (c.hodgesLehmann !== undefined) near(r!.hodgesLehmann!, c.hodgesLehmann);
      if (c.intervallo !== undefined) {
        expect(r!.interval).not.toBeNull();
        near(r!.interval!.low, c.intervallo.basso);
        near(r!.interval!.high, c.intervallo.alto);
        near(r!.interval!.confidence, c.intervallo.confidenza);
      } else {
        expect(r!.interval).toBeNull();
      }
    });
  }
});

describe('average ranks', () => {
  for (const [i, c] of golden.ranghiMedi.entries()) {
    it(`case ${i}`, () => expect(averageRanks(c.in)).toEqual(c.out));
  }
});

describe('power', () => {
  it('matches every combination', () => {
    for (const c of golden.potenza) {
      const v = signTestPower(c.blocchi, c.p, 0.05, c.unilaterale);
      expect(v).not.toBeNull();
      near(v!, c.potenza, 1e-10);
    }
  });
  it('minimum blocks', () => {
    for (const c of golden.blocchiMinimi) expect(minimumBlocks(0.05, c.unilaterale)).toBe(c.n);
  });
  it('binomial coefficients', () => {
    expect(binomialCoefficient(20, 10)).toBe(184756);
    expect(binomialCoefficient(6, 7)).toBe(0);
  });
});

describe('descriptive statistics', () => {
  const d = golden.descrittive;
  it('mean, median, sd, percentiles', () => {
    near(mean(d.campione)!, d.media);
    near(median(d.campione)!, d.mediana);
    near(standardDeviation(d.campione)!, d.deviazioneStandard);
    near(percentile(d.campione, 0.25)!, d.percentile25);
    near(percentile(d.campione, 0.75)!, d.percentile75);
  });
  it('entropy', () => {
    near(normalisedEntropy([2, 2, 2, 2])!, d.entropiaPiatta);
    near(normalisedEntropy([1, 2, 3, 4])!, d.entropiaUniforme);
    near(normalisedEntropy([2, 2, 2, 2, 2, 2, 2, 2, 3, 1])!, d.entropiaSchiacciata);
  });
});

describe('variance components', () => {
  for (const c of golden.componentiVarianza) {
    it(c.nome, () => {
      const r = varianceComponents(c.gruppi);
      expect(r).not.toBeNull();
      near(r!.withinDay, c.entroGiorno, 1e-10);
      near(r!.betweenDays, c.fraGiorni, 1e-10);
      near(r!.icc, c.icc, 1e-10);
      expect(r!.observations).toBe(c.osservazioni);
      expect(r!.days).toBe(c.giorni);
      near(r!.meanObservationsPerDay, c.mediaOsservazioniPerGiorno, 1e-10);
    });
  }
});

describe('autocorrelation', () => {
  for (const c of golden.autocorrelazione) {
    it(c.nome, () => {
      const series = new Map<string, number>();
      (c.valori as number[]).forEach((v, i) => {
        series.set(`2026-01-${String(i + 1).padStart(2, '0')}`, v);
      });
      const r = autocorrelation(series, 5);
      expect(r.length).toBe(c.ritardi.length);
      for (const [i, lag] of c.ritardi.entries()) {
        expect(r[i]!.lag).toBe(lag.ritardo);
        expect(r[i]!.pairs).toBe(lag.coppie);
        if (lag.r === null || lag.r === undefined) expect(r[i]!.r).toBeNull();
        else near(r[i]!.r!, lag.r, 1e-10);
      }
    });
  }
});

describe('minimum detectable difference', () => {
  it('matches every combination', () => {
    for (const c of golden.differenzaMinimaRilevabile) {
      const r = minimumDetectableDifference(c.sd, c.periodi, c.giorniPerPeriodo);
      expect(r).not.toBeNull();
      expect(r!.totalDays).toBe(c.giorniTotali);
      near(r!.minimumDifference, c.differenzaMinima, 1e-10);
    }
  });
  it('normal quantile', () => {
    for (const c of golden.quantileNormale) near(normalQuantile(c.p), c.z, 1e-9);
  });
});

describe('block sequence', () => {
  for (const c of golden.sequenzaBlocchi) {
    it(`seed ${c.seme}`, () => {
      expect(sequence(c.coppie, BigInt(c.seme))).toEqual(c.sequenza);
    });
  }
});

describe('feasibility', () => {
  it('matches every combination', () => {
    for (const c of golden.fattibilita) {
      const f = feasibility(c.coppie, 5, 4, c.unilaterale);
      expect(f.totalDays).toBe(c.giorniTotali);
      near(f.pFloor, c.pMinimoRaggiungibile, 1e-12);
      expect(f.agreementsNeeded).toBe(c.concordanzeNecessarie);
      near(f.power70, c.potenza70, 1e-10);
      near(f.power80, c.potenza80, 1e-10);
      near(f.power90, c.potenza90, 1e-10);
      expect(f.reachable).toBe(c.raggiungibile);
      expect(f.pairsToToleranceOne).toBe(c.coppiePerTollerareUnaDiscordanza);
    }
  });
});

describe('coverage', () => {
  it('matches day by day', () => {
    const answered = new Map<string, Set<Slot>>([
      ['2026-01-01', new Set<Slot>(['colazione', 'pranzo', 'cena'])],
      ['2026-01-02', new Set<Slot>(['colazione'])],
      ['2026-01-04', new Set<Slot>(['colazione', 'pranzo', 'cena', 'merenda'])],
    ]);
    const days = dailyCoverage({
      answeredSlots: answered,
      eventsPerDay: new Map([
        ['2026-01-01', 2],
        ['2026-01-03', 1],
      ]),
      daysWithOutcome: new Set(['2026-01-01', '2026-01-04']),
    });
    expect(days.length).toBe(golden.copertura.giornate.length);
    for (const [i, g] of golden.copertura.giornate.entries()) {
      expect(days[i]!.day).toBe(g.giorno);
      expect(days[i]!.expectedSlots).toBe(g.fasceAttese);
      expect(days[i]!.answeredSlots).toBe(g.fasceRisolte);
      expect(days[i]!.events).toBe(g.eventi);
      expect(days[i]!.hasOutcome).toBe(g.haEsito);
      near(days[i]!.fraction, g.frazione, 1e-12);
      expect(days[i]!.complete).toBe(g.completa);
    }
    const w = coverageWindow(days, 7, '2026-01-04');
    const gw = golden.copertura.finestra7;
    expect(w.days).toBe(gw.giorni);
    expect(w.completeDays).toBe(gw.giorniCompleti);
    near(w.meanFraction, gw.frazioneMedia, 1e-12);
    expect(w.daysWithOutcome).toBe(gw.giorniConEsito);
    expect(w.daysWithEvents).toBe(gw.giorniConEventi);
    expect(w.analysable).toBe(gw.analizzabile);
  });
});

describe('stool form scale', () => {
  it('matches labels, zones and abnormality', () => {
    expect(golden.formaFecale.length).toBe(7);
    for (const g of golden.formaFecale) {
      const f = g.valore as StoolForm;
      expect(STOOL_FORM_LABEL[f]).toBe(g.chiaveEtichetta);
      expect(STOOL_FORM_DESCRIPTION[f]).toBe(g.chiaveDescrizione);
      expect(formZone(f)).toBe(g.zona);
      expect(isAbnormal(f)).toBe(g.anormale);
    }
    expect(STOOL_FORMS.length).toBe(7);
  });
});

describe('concepts and codings', () => {
  it('matches the Swift side, including the asymmetry', () => {
    for (const g of golden.concetti) {
      const c = CONCEPTS[g.id];
      expect(c, `missing concept ${g.id}`).toBeDefined();
      expect(c!.label).toBe(g.etichettaInglese);
      const local = codingsFor(c!, false);
      expect(local.length).toBe(1);
      expect(local[0]!.system).toBe(g.codificaLocale.sistema);
      expect(local[0]!.code).toBe(g.codificaLocale.codice);
      expect(c!.external.length).toBe(g.codificheEsterne.length);
      for (const [i, e] of g.codificheEsterne.entries()) {
        expect(c!.external[i]!.system).toBe(e.sistema);
        expect(c!.external[i]!.code).toBe(e.codice);
        expect(c!.external[i]!.display).toBe(e.etichetta);
      }
    }
  });
  it('stool form carries no LOINC code, because none exists', () => {
    expect(CONCEPTS.formaFecale!.external.every((c) => c.system !== 'http://loinc.org')).toBe(true);
  });
});

describe('ingredient matching on the real ontology', () => {
  const matcher = new Matcher(
    orderBySpecificity(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (seed.ingredienti as any[]).map((v) => ({
        id: v.id,
        name: v.nomeEn,
        forms: [v.nomeIt, v.nomeEn, v.id, ...v.sinonimi, ...v.terminiLegacy2020],
      })),
    ),
  );

  for (const c of golden.riconoscimento) {
    it(`«${c.frase}»`, () => {
      const r = matcher.analyse(c.frase);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const expectedIds = (c.riconosciuti as any[]).map((x) => x.id);
      expect(r.matched.map((m) => m.id)).toEqual(expectedIds);
    });
  }

  it('normalisation matches', () => {
    for (const c of golden.normalizzazione) expect(normalise(c.in)).toBe(c.out);
  });

  it('edit distance matches', () => {
    for (const c of golden.distanza) expect(editDistance(c.a, c.b, c.limite)).toBe(c.out);
  });
});
