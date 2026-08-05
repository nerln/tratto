#!/usr/bin/env python3
"""
La domanda che il consiglio ha detto che nessuno aveva derivato:
l'esito ha abbastanza varianza da poterci misurare sopra un effetto?

Calcola dai dati reali del 2020:
 - distribuzione e dispersione dell'esito (per evento e per giorno)
 - scomposizione della varianza fra-giorni / entro-giorno
 - autocorrelazione seriale (lag 1..7) sulla serie giornaliera
 - differenza minima rilevabile per un crossover appaiato a k periodi
 - matrice di co-occorrenza degli ingredienti: quali coppie sono inseparabili
"""
import json, math, statistics as st
from collections import defaultdict, Counter
from datetime import date, timedelta
from itertools import combinations
from pathlib import Path

D = json.loads(Path("recovered.json").read_text())
ev = [e for e in D["events"] if e["consistency_legacy"] is not None]
evd = [e for e in D["events"] if e["discomfort_legacy"] is not None]

print("=" * 78)
print("1. DISPERSIONE DELL'ESITO")
print("=" * 78)


def descr(vals, nome):
    c = Counter(vals)
    n = len(vals)
    mean = st.mean(vals)
    sd = st.pstdev(vals)
    # entropia normalizzata: 1 = massima varieta', 0 = costante
    H = -sum((k / n) * math.log2(k / n) for k in c.values())
    Hmax = math.log2(len(c)) if len(c) > 1 else 1
    top2 = sum(v for _, v in c.most_common(2))
    print(f"\n{nome}: n={n}  media={mean:.2f}  SD={sd:.2f}")
    print(f"  distribuzione: {dict(sorted(c.items()))}")
    print(f"  due livelli piu' frequenti = {top2}/{n} = {100*top2/n:.1f}% delle osservazioni")
    print(f"  entropia normalizzata = {H/Hmax:.3f}  (1.0 = uniforme su tutti i livelli)")
    return mean, sd


m_c, sd_c = descr([e["consistency_legacy"] for e in ev], "Consistenza (per evento, 0-5)")
m_f, sd_f = descr([e["discomfort_legacy"] for e in evd], "Fastidio antecedente (per evento, 0-5)")

# aggregati giornalieri
per_day_c = defaultdict(list)
per_day_f = defaultdict(list)
for e in D["events"]:
    if e["consistency_legacy"] is not None:
        per_day_c[e["date"]].append(e["consistency_legacy"])
    if e["discomfort_legacy"] is not None:
        per_day_f[e["date"]].append(e["discomfort_legacy"])

day_mean_c = {d: st.mean(v) for d, v in per_day_c.items()}
day_mean_f = {d: st.mean(v) for d, v in per_day_f.items()}
day_n = {d: len(v) for d, v in per_day_c.items()}

print(f"\nMedia giornaliera consistenza: n={len(day_mean_c)} giorni, "
      f"media={st.mean(day_mean_c.values()):.2f}, SD fra giorni={st.pstdev(day_mean_c.values()):.3f}")
print(f"Media giornaliera fastidio   : n={len(day_mean_f)} giorni, "
      f"media={st.mean(day_mean_f.values()):.2f}, SD fra giorni={st.pstdev(day_mean_f.values()):.3f}")
print(f"Evacuazioni al giorno        : media={st.mean(day_n.values()):.2f}, "
      f"SD={st.pstdev(day_n.values()):.2f}, distribuzione={dict(sorted(Counter(day_n.values()).items()))}")

print()
print("=" * 78)
print("2. SCOMPOSIZIONE DELLA VARIANZA (fra giorni vs entro giorno)")
print("=" * 78)


def var_components(per_day):
    """ANOVA a una via a effetti casuali: quota di varianza spiegata dal giorno (ICC)."""
    groups = [v for v in per_day.values() if len(v) >= 1]
    k = len(groups)
    N = sum(len(g) for g in groups)
    grand = sum(sum(g) for g in groups) / N
    ss_between = sum(len(g) * (st.mean(g) - grand) ** 2 for g in groups)
    ss_within = sum(sum((x - st.mean(g)) ** 2 for x in g) for g in groups)
    df_b, df_w = k - 1, N - k
    ms_b = ss_between / df_b if df_b else float("nan")
    ms_w = ss_within / df_w if df_w > 0 else 0.0
    # n0 per gruppi di dimensione diversa
    n0 = (N - sum(len(g) ** 2 for g in groups) / N) / (k - 1) if k > 1 else 1
    var_b = max(0.0, (ms_b - ms_w) / n0) if n0 else 0.0
    icc = var_b / (var_b + ms_w) if (var_b + ms_w) > 0 else float("nan")
    return ms_b, ms_w, var_b, icc, n0, N, k


for nome, pd_ in (("Consistenza", per_day_c), ("Fastidio", per_day_f)):
    ms_b, ms_w, var_b, icc, n0, N, k = var_components(pd_)
    print(f"\n{nome}: {N} eventi in {k} giorni (media {n0:.2f} eventi/giorno)")
    print(f"  varianza ENTRO il giorno (MS_within) = {ms_w:.4f}")
    print(f"  varianza FRA i giorni (stimata)      = {var_b:.4f}")
    print(f"  ICC = {icc:.3f}  -> il {100*icc:.0f}% della varianza sta fra giorni diversi,")
    print(f"       il restante {100*(1-icc):.0f}% e' rumore fra evacuazioni dello stesso giorno.")

print()
print("=" * 78)
print("3. AUTOCORRELAZIONE DELLA SERIE GIORNALIERA")
print("=" * 78)


def acf(series_by_date, maxlag=7):
    ds = sorted(series_by_date)
    d0, d1 = date.fromisoformat(ds[0]), date.fromisoformat(ds[-1])
    grid = []
    d = d0
    while d <= d1:
        grid.append(series_by_date.get(d.isoformat()))
        d += timedelta(days=1)
    out = []
    for lag in range(1, maxlag + 1):
        pairs = [(grid[i], grid[i + lag]) for i in range(len(grid) - lag)
                 if grid[i] is not None and grid[i + lag] is not None]
        if len(pairs) < 8:
            out.append((lag, None, len(pairs))); continue
        xs = [p[0] for p in pairs]; ys = [p[1] for p in pairs]
        mx, my = st.mean(xs), st.mean(ys)
        num = sum((x - mx) * (y - my) for x, y in pairs)
        den = math.sqrt(sum((x - mx) ** 2 for x in xs) * sum((y - my) ** 2 for y in ys))
        out.append((lag, num / den if den else None, len(pairs)))
    return out


for nome, dm in (("Consistenza", day_mean_c), ("Fastidio", day_mean_f)):
    print(f"\n{nome} (media giornaliera):")
    for lag, r, n in acf(dm):
        s = f"{r:+.3f}" if r is not None else "  n/d"
        flag = "  <-- i giorni consecutivi NON sono indipendenti" if (r is not None and abs(r) > 0.3) else ""
        print(f"  lag {lag} giorni: r = {s}   (n={n} coppie){flag}")

print()
print("=" * 78)
print("4. DIFFERENZA MINIMA RILEVABILE (crossover appaiato a k periodi)")
print("=" * 78)
sd_day = st.pstdev(day_mean_c.values())
print(f"\nSD della media giornaliera di consistenza = {sd_day:.3f} punti (scala 0-5)")
print("Un periodo = media di piu' giorni, quindi SD del periodo = SD_giorno / sqrt(giorni per periodo).")
print("Test t appaiato bilaterale, alfa=0.05, potenza 80% -> serve delta >= 2.98 * SD_diff / sqrt(k)\n")
print(f"{'k periodi':>10} {'gg/periodo':>11} {'SD diff':>9} {'delta minimo':>13}  interpretazione")
for k in (4, 6, 8, 10):
    for gpp in (3, 5, 7):
        sd_per = sd_day / math.sqrt(gpp)
        sd_diff = sd_per * math.sqrt(2)          # differenza fra due periodi appaiati
        delta = 2.98 * sd_diff / math.sqrt(k)
        giorni = k * gpp * 2                      # k coppie A/B
        interp = "irrealistico" if delta > 1.0 else ("plausibile" if delta > 0.5 else "rilevabile")
        print(f"{k:>10} {gpp:>11} {sd_diff:>9.3f} {delta:>13.2f}  {interp:12s} ({giorni} giorni di protocollo)")

print("\nNota: e' il caso OTTIMISTICO. Assume indipendenza fra periodi (l'autocorrelazione sopra")
print("dice quanto e' vero) e nessuna perdita di aderenza.")

print()
print("=" * 78)
print("5. CO-OCCORRENZA: QUALI INGREDIENTI SONO INSEPARABILI")
print("=" * 78)
# ontologia unificata: alimenti + condimenti nello stesso spazio
meal_sets = []
for m in D["meals"]:
    s = set(m["food_keys"])
    s |= {c.strip().lower().replace(" ", "_") for c in m["condiments"]}
    meal_sets.append(s)
cnt = Counter()
for s in meal_sets:
    cnt.update(s)
print(f"\nIngredienti distinti nell'ontologia unificata: {len(cnt)}")
for soglia in (5, 10, 15, 20):
    print(f"  con >= {soglia:2d} esposizioni: {sum(1 for v in cnt.values() if v >= soglia)}")

analizzabili = [k for k, v in cnt.items() if v >= 10]
print(f"\nInsieme analizzabile (>=10 esposizioni): {len(analizzabili)} ingredienti")
print("  " + ", ".join(f"{k}({cnt[k]})" for k in sorted(analizzabili, key=lambda x: -cnt[x])))

print("\nCoppie con indice di Jaccard >= 0.6 (praticamente inseparabili nei dati):")
found = 0
for a, b in combinations(sorted(analizzabili), 2):
    ia = {i for i, s in enumerate(meal_sets) if a in s}
    ib = {i for i, s in enumerate(meal_sets) if b in s}
    j = len(ia & ib) / len(ia | ib) if (ia | ib) else 0
    if j >= 0.6:
        print(f"  {a} / {b}: Jaccard {j:.2f}  (insieme {len(ia&ib)} volte, {a} {len(ia)}, {b} {len(ib)})")
        found += 1
if not found:
    print("  nessuna: nessuna coppia dell'insieme analizzabile e' completamente confusa.")
    print("  Le piu' vicine:")
    js = []
    for a, b in combinations(sorted(analizzabili), 2):
        ia = {i for i, s in enumerate(meal_sets) if a in s}
        ib = {i for i, s in enumerate(meal_sets) if b in s}
        j = len(ia & ib) / len(ia | ib) if (ia | ib) else 0
        js.append((j, a, b, len(ia & ib)))
    for j, a, b, k in sorted(js, reverse=True)[:6]:
        print(f"    {a} / {b}: Jaccard {j:.2f} (insieme {k} volte)")

print()
print("=" * 78)
print("6. QUANTI GIORNI SONO DAVVERO UTILIZZABILI")
print("=" * 78)
days_food = {m["date"] for m in D["meals"]}
days_ev = {e["date"] for e in D["events"]}
both = days_food & days_ev
# un giorno e' "completo" se ha almeno 3 pasti registrati (su 6 fasce)
meals_per_day = Counter(m["date"] for m in D["meals"])
complete = {d for d in both if meals_per_day[d] >= 3}
print(f"\ngiorni con cibo E evacuazioni      : {len(both)}")
print(f"giorni con >= 3 pasti registrati   : {sum(1 for d in meals_per_day if meals_per_day[d]>=3)}")
print(f"giorni 'completi' (>=3 pasti + eventi): {len(complete)}")
print(f"distribuzione pasti/giorno: {dict(sorted(Counter(meals_per_day.values()).items()))}")
print("\n-> l'esposizione alimentare e' nota solo parzialmente: un giorno con 2 pasti su 6")
print("   registrati non e' un giorno osservato, e' un giorno per lo piu' ignoto.")
