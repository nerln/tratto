#!/usr/bin/env python3
"""
Recupero del dataset originale "Progetto-fondamenti-Nerelli" (2020).

Legge i CSV esportati dal foglio Google e ricostruisce un dataset normalizzato,
denormalizzando la catena Giorno pasto -> Portate -> Pasti/Portate condimenti -> Condimenti.

Output: recovered.json  (+ report di qualita' su stdout)

Nessuna interpretazione clinica qui dentro: le scale restano quelle originali
(Consistenza 0-5 dove 0 = peggio, Fastidio antecedente 0-5 dove 0 = meglio).
"""
import csv, json, re, sys, unicodedata
from pathlib import Path
from datetime import datetime, date, time
from collections import defaultdict, Counter

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "recovered.json")

SLOTS = ["Colazione", "Spuntino_mattina", "Pranzo",
         "Spuntino_pomeriggio", "Cena", "Spuntino_cena"]
# ora nominale usata solo per ordinare gli slot, non e' un dato reale
SLOT_ORDER = {s: i for i, s in enumerate(SLOTS)}

issues = []


def note(kind, msg):
    issues.append({"kind": kind, "msg": msg})


def read(name):
    p = SRC / name
    with p.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def blank(v):
    return v is None or str(v).strip() == ""


def norm_key(s):
    """chiave di confronto per i nomi di alimenti/condimenti"""
    s = str(s).strip().lower().replace(" ", "_")
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


def parse_dt(s):
    """02/05/2020 9.30.00 -> (date, time)"""
    s = str(s).strip()
    m = re.match(r"^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2})\.(\d{2})\.(\d{2})$", s)
    if not m:
        return None, None
    d, mo, y, h, mi, se = (int(x) for x in m.groups())
    return date(y, mo, d), time(h, mi, se)


def parse_day(s):
    """02-05-2020 -> date"""
    s = str(s).strip()
    m = re.match(r"^(\d{1,2})-(\d{1,2})-(\d{4})$", s)
    if not m:
        return None
    d, mo, y = (int(x) for x in m.groups())
    return date(y, mo, d)


# ---------------------------------------------------------------- anagrafiche
pasti_rows = read("Progetto - Pasti.csv")
foods = []
seen = set()
for r in pasti_rows:
    n = (r.get("Pasti") or "").strip()
    if not n:
        continue
    k = norm_key(n)
    if k in seen:
        note("dup", f"alimento duplicato in Pasti.csv: {n}")
        continue
    seen.add(k)
    foods.append({"id": (r.get("ID") or "").strip(), "name": n, "key": k})

cond_rows = read("Progetto - Condimenti.csv")
conds = []
seen_c = set()
for r in cond_rows:
    n = (r.get("nome condimento") or "").strip()
    if not n:
        continue
    k = norm_key(n)
    if k in seen_c:
        note("dup", f"condimento duplicato in Condimenti.csv: {n}")
        continue
    seen_c.add(k)
    conds.append({"id": (r.get("ID") or "").strip(), "name": n, "key": k})

# tipi: alimento -> categorie (fino a 3). I nomi hanno spazi/typo, normalizzo.
TYPE_FIX = {"dolce": "Dolci", "verdura": "Verdura"}
tipi_rows = read("Tipi di pasti.csv")
food_types = {}
for r in tipi_rows:
    n = (r.get("Pasti") or "").strip()
    if not n:
        continue
    ts = []
    for c in ("Tipo_1", "Tipo_2", "Tipo_3"):
        v = (r.get(c) or "").strip()
        if v:
            v = v.strip()
            ts.append(TYPE_FIX.get(v.lower(), v))
    food_types[norm_key(n)] = sorted(set(ts))

for f in foods:
    if f["key"] not in food_types:
        note("missing_type", f"alimento senza categoria: {f['name']}")

# ------------------------------------------------------- gruppi di condimenti
pc_rows = read("Progetto - Portate condimenti.csv")
cond_groups = {}
for r in pc_rows:
    cid = (r.get("ID") or "").strip()
    if not cid:
        continue
    items = []
    for i in range(1, 9):
        v = (r.get(f"Condimento_{i}") or "").strip()
        if v:
            items.append(v)
    cond_groups[cid] = items

known_cond = {c["key"] for c in conds}
for cid, items in cond_groups.items():
    for it in items:
        if norm_key(it) not in known_cond:
            note("orphan_cond", f"{cid}: condimento non in anagrafica: {it}")

# --------------------------------------------------------------------- portate
# ID, Pasto_1, Condimento_pasto_1, ... Pasto_4, Condimento_pasto_4, Pasto_5
# (Pasto_5 non ha colonna condimento nell'originale)
port_rows = read("Progetto - Portate.csv")
courses = {}
known_food = {f["key"] for f in foods}
for r in port_rows:
    pid = (r.get("ID") or "").strip()
    if not pid:
        continue
    comps = []
    for i in range(1, 6):
        fname = (r.get(f"Pasto_{i}") or "").strip()
        if not fname:
            continue
        cgid = (r.get(f"Condimento_pasto_{i}") or "").strip() if i <= 4 else ""
        if norm_key(fname) not in known_food:
            note("orphan_food", f"{pid}: alimento non in anagrafica: {fname}")
        if cgid and cgid not in cond_groups:
            note("orphan_group", f"{pid}: gruppo condimenti inesistente: {cgid}")
        comps.append({
            "food": fname,
            "food_key": norm_key(fname),
            "condiment_group": cgid or None,
            "condiments": cond_groups.get(cgid, []) if cgid else [],
        })
    courses[pid] = comps

# ------------------------------------------------------------ giorno -> pasti
gp_rows = read("Progetto - Giorno pasto.csv")
meals = []          # un record per (giorno, slot) effettivamente compilato
days_with_food = set()
for r in gp_rows:
    d = parse_day(r.get("Giorno") or "")
    if d is None:
        if not blank(r.get("Giorno")):
            note("bad_date", f"data non parsabile in Giorno pasto: {r.get('Giorno')}")
        continue
    for slot in SLOTS:
        pid = (r.get(slot) or "").strip()
        if not pid:
            continue
        if pid not in courses:
            note("orphan_course", f"{d} {slot}: portata inesistente {pid}")
            continue
        comps = courses[pid]
        meals.append({
            "date": d.isoformat(),
            "slot": slot,
            "slot_index": SLOT_ORDER[slot],
            "course_id": pid,
            "foods": [c["food"] for c in comps],
            "food_keys": [c["food_key"] for c in comps],
            "condiments": sorted({x for c in comps for x in c["condiments"]}),
            "components": comps,
        })
        days_with_food.add(d)

# --------------------------------------------------------------- evacuazioni
cc_rows = read("Progetto - Cacca.csv")
events = []
for r in cc_rows:
    eid = (r.get("ID") or "").strip()
    raw = (r.get("Data") or "").strip()
    if blank(raw):
        if eid:
            note("empty_event", f"evento {eid} senza data: riga scartata")
        continue
    d, t = parse_dt(raw)
    if d is None:
        note("bad_date", f"timestamp non parsabile: {raw}")
        continue

    def num(col):
        v = (r.get(col) or "").strip().replace(",", ".")
        if v == "":
            return None
        try:
            return float(v)
        except ValueError:
            note("bad_num", f"{eid}: valore non numerico in {col}: {v!r}")
            return None

    cons = num("Consistenza")
    fast = num("Fastidio antecedente")
    if cons is None:
        note("missing_value", f"{eid} ({d}): Consistenza mancante")
    if fast is None:
        note("missing_value", f"{eid} ({d}): Fastidio antecedente mancante")
    events.append({
        "id": eid,
        "date": d.isoformat(),
        "time": t.isoformat(timespec="minutes"),
        "consistency_legacy": cons,     # 0-5, 0 = peggio (NON Bristol)
        "discomfort_legacy": fast,      # 0-5, 0 = meglio
    })

events.sort(key=lambda e: (e["date"], e["time"]))

# ------------------------------------------------------------------- referto
all_days = sorted({m["date"] for m in meals} | {e["date"] for e in events})
d0, d1 = (date.fromisoformat(all_days[0]), date.fromisoformat(all_days[-1])) if all_days else (None, None)
span = (d1 - d0).days + 1 if d0 else 0

days_food = {m["date"] for m in meals}
days_ev = {e["date"] for e in events}

food_freq = Counter()
for m in meals:
    for fk in set(m["food_keys"]):
        food_freq[fk] += 1
cond_freq = Counter()
for m in meals:
    for c in set(m["condiments"]):
        cond_freq[norm_key(c)] += 1

dataset = {
    "source": "github.com/nerln/Progetto-fondamenti-Nerelli",
    "recovered_at": None,   # riempito dal chiamante, non usiamo l'orologio qui
    "scales": {
        "consistency_legacy": "0-5, 0 = peggiore. NON e' la scala di Bristol: nel modello originale il punteggio cresce monotonicamente con il valore.",
        "discomfort_legacy": "0-5, 0 = migliore (nessun fastidio prima dell'evacuazione).",
    },
    "period": {"from": all_days[0] if all_days else None,
               "to": all_days[-1] if all_days else None,
               "calendar_days": span},
    "foods": foods,
    "condiments": conds,
    "food_types": food_types,
    "condiment_groups": cond_groups,
    "courses": courses,
    "meals": meals,
    "events": events,
    "issues": issues,
}
OUT.write_text(json.dumps(dataset, ensure_ascii=False, indent=1))

print(f"periodo            : {all_days[0]} -> {all_days[-1]}  ({span} giorni di calendario)")
print(f"alimenti           : {len(foods)}")
print(f"condimenti         : {len(conds)}")
print(f"gruppi condimenti  : {len(cond_groups)}")
print(f"portate            : {len(courses)}")
print(f"pasti registrati   : {len(meals)}  su {len(days_food)} giorni distinti")
print(f"evacuazioni        : {len(events)} su {len(days_ev)} giorni distinti")
print(f"giorni con ENTRAMBI: {len(days_food & days_ev)}")
print(f"giorni solo cibo   : {len(days_food - days_ev)}")
print(f"giorni solo eventi : {len(days_ev - days_food)}")
print(f"copertura del periodo: {len(days_food | days_ev)}/{span} giorni")
print()
print("distribuzione pasti per fascia:")
for s in SLOTS:
    print(f"  {s:22s} {sum(1 for m in meals if m['slot'] == s):3d}")
print()
print("distribuzione Consistenza (legacy):", dict(sorted(Counter(e['consistency_legacy'] for e in events).items(), key=lambda x: (x[0] is None, x[0]))))
print("distribuzione Fastidio    (legacy):", dict(sorted(Counter(e['discomfort_legacy'] for e in events).items(), key=lambda x: (x[0] is None, x[0]))))
print()
print("alimenti mai comparsi in un pasto:", sum(1 for f in foods if food_freq[f['key']] == 0), "/", len(foods))
print("top 12 alimenti per n. di pasti:")
for k, n in food_freq.most_common(12):
    print(f"  {k:32s} {n:3d}")
print()
print(f"potenza: alimenti presenti in >= 5 pasti: {sum(1 for v in food_freq.values() if v >= 5)}")
print(f"         alimenti presenti in >= 10 pasti: {sum(1 for v in food_freq.values() if v >= 10)}")
print()
by_kind = Counter(i["kind"] for i in issues)
print("problemi di qualita' dei dati:", dict(by_kind), f"(totale {len(issues)})")
for i in issues[:25]:
    print("  -", i["kind"], "|", i["msg"])
if len(issues) > 25:
    print(f"  ... e altri {len(issues)-25}")
