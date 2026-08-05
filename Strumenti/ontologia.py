#!/usr/bin/env python3
"""
Costruisce l'ontologia canonica degli ingredienti a partire dalle DUE anagrafiche
separate del 2020 (83 "alimenti" + 79 "condimenti", che si sovrappongono).

La mappatura qui sotto e' scritta a mano: e' una decisione, non un algoritmo.
Ogni termine del 2020 finisce in esattamente una voce canonica, e il termine
originale resta come sinonimo, cosi' l'archivio storico resta leggibile.

Il campo `gruppo` e' deliberatamente povero: contiene solo cio' che e' conoscenza
comune e non controversa (lattosio, glutine, caffeina, alcol). NON e' un dato
clinico e non viene da nessuna tabella FODMAP: quelle di Monash non sono
utilizzabili legalmente e l'unica aperta e' svedese e incompleta.

Uso:  python3 ontologia.py <recovered.json> <seed-ontologia.json>
"""
import json, sys, unicodedata
from collections import Counter
from pathlib import Path

# (canonico, categoria, gruppi ipotizzati, [termini del 2020 che ci confluiscono])
MAPPA = [
    # --- cereali e derivati
    ("pasta_di_grano",      "Pasta",         ["glutine"], ["pasta"]),
    ("pasta_integrale",     "Pasta",         ["glutine"], ["pasta_integrale"]),
    ("pasta_di_semola",     "Pasta",         ["glutine"], ["pasta_semola"]),
    ("pasta_di_mais",       "Pasta",         [],          ["pasta_mais"]),
    ("tortelli",            "Pasta ripiena", ["glutine"], ["tortelli"]),
    ("gnocchi_integrali",   "Pasta",         ["glutine"], ["gnocchi_integrali"]),
    ("riso",                "Cereali",       [],          ["riso"]),
    ("riso_soffiato",       "Cereali",       [],          ["riso_soffiato"]),
    ("galletta_di_riso",    "Cereali",       [],          ["galletta_riso"]),
    ("corn_flakes",         "Cereali",       [],          ["corn_flakes"]),
    ("polenta",             "Cereali",       [],          ["polenta"]),
    ("pangrattato",         "Cereali",       ["glutine"], ["pan_grattato"]),
    ("pangrattato_senza_glutine", "Cereali", [],          ["pan_grattato_senza_glutine"]),
    # --- pane e affini
    ("pane_di_semola",      "Pane",          ["glutine"], ["pane_semola"]),
    ("pane_integrale",      "Pane",          ["glutine"], ["pane_integrale_semola"]),
    ("pane_alle_noci",      "Pane",          ["glutine"], ["pane_noci_integrale_semola"]),
    ("pane_alle_olive",     "Pane",          ["glutine"], ["pane_olive_integrale_semola"]),
    ("pane_senza_glutine",  "Pane",          [],          ["pane_senza_glutine"]),
    ("pancarre",            "Pane",          ["glutine"], ["pancarré"]),
    ("pancarre_integrale",  "Pane",          ["glutine"], ["pancarrè_integrale"]),
    ("pancarre_senza_glutine", "Pane",       [],          ["pancarré_senza_glutine"]),
    ("focaccia",            "Pane",          ["glutine"], ["focaccia"]),
    ("grissini",            "Pane",          ["glutine"], ["grissini"]),
    ("piadina_senza_glutine", "Pane",        [],          ["piadina_senza_glutine"]),
    # --- frutta
    ("mela",       "Frutta", [], ["mela"]),
    ("pera",       "Frutta", [], ["pera"]),
    ("banana",     "Frutta", [], ["banana"]),
    ("arancia",    "Frutta", [], ["arancia"]),
    ("limone",     "Frutta", [], ["limone"]),
    # --- verdura e tuberi
    ("carota",           "Verdura", [], ["carota"]),
    ("finocchio",        "Verdura", [], ["finocchio"]),
    ("zucchina",         "Verdura", [], ["zucchine"]),
    ("cipolla",          "Verdura", [], ["cipolla"]),
    ("pomodoro",         "Verdura", [], ["pomodoro"]),
    ("insalata",         "Verdura", [], ["insalata", "lattuga"]),
    ("sedano",           "Verdura", [], ["sedano"]),
    ("spinaci",          "Verdura", [], ["spinaci"]),
    ("asparagi",         "Verdura", [], ["asparagi"]),
    ("carciofo",         "Verdura", [], ["carciofo"]),
    ("melanzana",        "Verdura", [], ["melanzane"]),
    ("peperone",         "Verdura", [], ["peperoni"]),
    ("cavolo_cappuccio", "Verdura", [], ["cavolo_cappuccio"]),
    ("funghi",           "Verdura", [], ["funghi"]),
    ("verdure_miste",    "Verdura", [], ["verdure_miste"]),
    ("patata",           "Tuberi",  [], ["patata"]),
    # --- legumi
    ("ceci",                "Legumi", [], ["ceci"]),
    ("fagioli_cannellini",  "Legumi", [], ["cannellino"]),
    # --- carne
    ("pollo",         "Carne bianca", [], ["fettina_pollo", "cosciotti_pollo",
                                           "pollo_allo_spiedo", "pollo_pezzetti"]),
    ("carne_trita",   "Carne rossa",  [], ["carne_trita"]),
    ("carne_a_pezzi", "Carne rossa",  [], ["carne_pezzetti"]),
    ("agnello",       "Carne rossa",  [], ["agnello"]),
    ("salsiccia",     "Carne rossa",  [], ["salsiccia"]),
    ("spiedini_di_maiale", "Carne rossa", [], ["spiedini_maiale"]),
    # --- salumi
    ("speck",            "Salumi", [], ["speck"]),
    ("salame",           "Salumi", [], ["salame"]),
    ("salame_piccante",  "Salumi", [], ["salame_piccante"]),
    ("salame_d_oca",     "Salumi", [], ["salame_oca"]),
    ("prosciutto_crudo", "Salumi", [], ["prosciutto_crudo"]),
    ("prosciutto_cotto", "Salumi", [], ["prosciutto_cotto"]),
    ("mortadella",       "Salumi", [], ["mortadella"]),
    ("pancetta",         "Salumi", [], ["pancetta"]),
    ("wurstel",          "Salumi", [], ["wurstel"]),
    # --- pesce
    ("merluzzo",           "Pesce", [], ["merluzzo"]),
    ("baccala",            "Pesce", [], ["baccalà"]),
    ("salmone",            "Pesce", [], ["salmone"]),
    ("salmone_affumicato", "Pesce", [], ["salmone_affumicato"]),
    ("tonno",              "Pesce", [], ["tonno"]),
    ("sgombro",            "Pesce", [], ["sgombro"]),
    ("acciughe",           "Pesce", [], ["acciughine"]),
    ("gamberetti",         "Pesce", [], ["gamberetti"]),
    ("frutti_di_mare",     "Pesce", [], ["frutti_di_mare"]),
    # --- uova
    ("uovo",   "Uova", [], ["uova", "uovo"]),
    ("tuorlo", "Uova", [], ["tuorlo_uovo"]),
    # --- latticini e formaggi
    ("latte_senza_lattosio",     "Latticini", [],           ["latte_senza_lattosio"]),
    ("yogurt",                   "Latticini", ["lattosio"], ["yogurt"]),
    ("panna",                    "Latticini", ["lattosio"], ["panna_con_lattosio"]),
    ("panna_senza_lattosio",     "Latticini", [],           ["panna_senza_lattosio"]),
    ("parmigiano",               "Formaggi",  [],           ["parmigiano"]),
    ("mozzarella",               "Formaggi",  ["lattosio"], ["mozzarella"]),
    ("formaggio_senza_lattosio", "Formaggi",  [],           ["formaggio_senza_lattosio",
                                                             "sottilette_senza_lattosio"]),
    # --- grassi e condimenti
    ("olio_di_oliva",   "Grassi",     [],           ["olio"]),
    ("burro",           "Grassi",     ["lattosio"], ["burro"]),
    ("olive_verdi",     "Condimenti", [],           ["olive_verdi"]),
    ("olive_nere",      "Condimenti", [],           ["olive_nere"]),
    ("capperi",         "Condimenti", [],           ["capperi"]),
    ("aceto_di_vino",   "Condimenti", [],           ["aceto_di_vino"]),
    ("salsa_di_soia",   "Condimenti", ["glutine"],  ["salsa_soia"]),
    ("salsa_di_pomodoro", "Condimenti", [],         ["salsa_pomodoro"]),
    ("pesto_genovese",  "Condimenti", [],           ["pesto_genovese"]),
    ("pesto_ricotta_noci", "Condimenti", ["lattosio"], ["pesto_ricotta_noci"]),
    ("marmellata",      "Condimenti", [],           ["marmellata"]),
    # --- erbe e spezie
    ("basilico",       "Erbe e spezie", [], ["basilico"]),
    ("origano",        "Erbe e spezie", [], ["origano"]),
    ("erba_cipollina", "Erbe e spezie", [], ["erba_cipollina"]),
    ("zenzero",        "Erbe e spezie", [], ["zenzero"]),
    ("curry",          "Erbe e spezie", [], ["curry"]),
    ("zafferano",      "Erbe e spezie", [], ["zafferano"]),
    ("pepe_nero",      "Erbe e spezie", [], ["pepe_nero"]),
    ("vaniglia",       "Erbe e spezie", [], ["vaniglia"]),
    # --- frutta secca e semi
    ("pistacchio",     "Frutta secca", [], ["pistacchio"]),
    ("arachidi",       "Frutta secca", [], ["noccioline"]),
    ("semi_di_sesamo", "Semi",         [], ["semi_sesamo"]),
    # --- dolci
    ("cioccolato_fondente",  "Dolci", [],           ["cioccolata_fondente"]),
    ("cioccolato_al_latte",  "Dolci", ["lattosio"], ["cioccolata_al_latte", "cioccolato"]),
    ("crema_di_nocciole",    "Dolci", ["lattosio"], ["cioccolata_nocciolata", "choco_cream"]),
    ("gelato",               "Dolci", ["lattosio"], ["gelato"]),
    ("gelato_senza_lattosio", "Dolci", [],          ["cornetto_sammontana_no_lattosio"]),
    ("budino",               "Dolci", ["lattosio"], ["budino"]),
    ("torta_di_mele",        "Dolci", ["glutine"],  ["torta_mele"]),
    ("torta_foresta_nera",   "Dolci", ["glutine", "lattosio"], ["foresta_nera"]),
    ("zuppa_inglese",        "Dolci", ["glutine", "lattosio"], ["zuppa_inglese"]),
    ("gubana",               "Dolci", ["glutine"],  ["gubana"]),
    ("krapfen",              "Dolci", ["glutine"],  ["krapfen"]),
    ("cornetto_alla_crema",  "Dolci", ["glutine", "lattosio"], ["cornetto_crema"]),
    ("cantuccini_senza_glutine", "Dolci", [],       ["cantuccini_senza_glutine"]),
    # --- bevande
    ("caffe",             "Bevande", ["caffeina"], ["caffè"]),
    ("caffe_d_orzo",      "Bevande", [],           ["caffè_orzo"]),
    ("te_alla_pesca",     "Bevande", ["caffeina"], ["te_pesca"]),
    ("tisana",            "Bevande", [],           ["tisana_frutti_bosco"]),
    ("cioccolata_calda",  "Bevande", ["lattosio"], ["cioccolata_calda"]),
    ("coca_cola",         "Bevande", ["caffeina"], ["coca_cola"]),
    ("latte_di_mandorla", "Bevande", [],           ["latte_mandorla"]),
    # --- piatti composti (restano una voce sola: scomporli a posteriori
    #     inventerebbe ingredienti che nel 2020 non sono stati registrati)
    ("pizza",              "Piatti composti", ["glutine"], ["pizza"]),
    ("sushi",              "Piatti composti", [],          ["sushi"]),
    ("hamburger",          "Piatti composti", ["glutine"], ["hamburger"]),
    ("cotoletta",          "Piatti composti", ["glutine"], ["cotolette"]),
    ("involtini",          "Piatti composti", [],          ["involtini"]),
    ("spezzatino",         "Piatti composti", [],          ["spezzatino"]),
    ("polpette_di_carne",  "Piatti composti", ["glutine"], ["polpette_carne"]),
    ("polpette_di_carne_senza_glutine", "Piatti composti", [], ["polpette_carne_senza_glutine"]),
    ("polpette_di_tonno",  "Piatti composti", [],          ["polpette_tonno"]),
    ("canederli",          "Piatti composti", ["glutine"], ["canederli"]),
    ("gnocchi_di_sauris",  "Piatti composti", ["glutine"], ["gnocchi_di_sauris"]),
    ("frico",              "Piatti composti", ["lattosio"], ["frico"]),
    ("erbazzone",          "Piatti composti", ["glutine"], ["erbazzone_reggiano"]),
    ("rustico",            "Piatti composti", ["glutine"], ["rustico"]),
    ("panzerotto",         "Piatti composti", ["glutine"], ["panzerotto"]),
    ("empanada",           "Piatti composti", ["glutine"], ["empanada_gallega"]),
    ("tortilla_di_patate", "Piatti composti", [],          ["tortilla"]),
    ("rotolo_speck_formaggio", "Piatti composti", ["glutine", "lattosio"], ["rotolo_speck_formaggio"]),
    ("pollo_tikka_masala", "Piatti composti", ["lattosio"], ["pollo tikka masala"]),
    ("patatine_fritte",    "Piatti composti", [],          ["patatine"]),
]

ETICHETTE = {
    "pasta_di_grano": "Pasta", "pasta_integrale": "Pasta integrale",
    "pasta_di_semola": "Pasta di semola", "pasta_di_mais": "Pasta di mais",
    "gnocchi_integrali": "Gnocchi integrali", "riso_soffiato": "Riso soffiato",
    "galletta_di_riso": "Gallette di riso", "pangrattato": "Pangrattato",
    "pangrattato_senza_glutine": "Pangrattato senza glutine",
    "pane_di_semola": "Pane di semola", "pane_integrale": "Pane integrale",
    "pane_alle_noci": "Pane alle noci", "pane_alle_olive": "Pane alle olive",
    "pane_senza_glutine": "Pane senza glutine", "pancarre": "Pancarré",
    "pancarre_integrale": "Pancarré integrale",
    "pancarre_senza_glutine": "Pancarré senza glutine",
    "piadina_senza_glutine": "Piadina senza glutine",
    "olio_di_oliva": "Olio d'oliva", "salsa_di_soia": "Salsa di soia",
    "salsa_di_pomodoro": "Salsa di pomodoro", "aceto_di_vino": "Aceto di vino",
    "pesto_ricotta_noci": "Pesto ricotta e noci", "erba_cipollina": "Erba cipollina",
    "semi_di_sesamo": "Semi di sesamo", "cioccolato_fondente": "Cioccolato fondente",
    "cioccolato_al_latte": "Cioccolato al latte", "crema_di_nocciole": "Crema di nocciole",
    "gelato_senza_lattosio": "Gelato senza lattosio", "torta_di_mele": "Torta di mele",
    "torta_foresta_nera": "Torta foresta nera", "zuppa_inglese": "Zuppa inglese",
    "cornetto_alla_crema": "Cornetto alla crema",
    "cantuccini_senza_glutine": "Cantuccini senza glutine",
    "caffe": "Caffè", "caffe_d_orzo": "Caffè d'orzo", "te_alla_pesca": "Tè alla pesca",
    "cioccolata_calda": "Cioccolata calda", "coca_cola": "Coca-Cola",
    "latte_di_mandorla": "Latte di mandorla", "latte_senza_lattosio": "Latte senza lattosio",
    "panna_senza_lattosio": "Panna senza lattosio",
    "formaggio_senza_lattosio": "Formaggio senza lattosio",
    "polpette_di_carne": "Polpette di carne",
    "polpette_di_carne_senza_glutine": "Polpette di carne senza glutine",
    "polpette_di_tonno": "Polpette di tonno", "gnocchi_di_sauris": "Gnocchi di Sauris",
    "rotolo_speck_formaggio": "Rotolo speck e formaggio",
    "pollo_tikka_masala": "Pollo tikka masala", "tortilla_di_patate": "Tortilla di patate",
    "patatine_fritte": "Patatine fritte", "carne_trita": "Carne trita",
    "carne_a_pezzi": "Carne a pezzi", "spiedini_di_maiale": "Spiedini di maiale",
    "salame_d_oca": "Salame d'oca", "salame_piccante": "Salame piccante",
    "prosciutto_crudo": "Prosciutto crudo", "prosciutto_cotto": "Prosciutto cotto",
    "salmone_affumicato": "Salmone affumicato", "frutti_di_mare": "Frutti di mare",
    "fagioli_cannellini": "Fagioli cannellini", "cavolo_cappuccio": "Cavolo cappuccio",
    "verdure_miste": "Verdure miste", "olive_verdi": "Olive verdi",
    "olive_nere": "Olive nere", "pepe_nero": "Pepe nero", "baccala": "Baccalà",
}


def norm(s):
    s = str(s).strip().lower().replace(" ", "_")
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


def etichetta(cid):
    if cid in ETICHETTE:
        return ETICHETTE[cid]
    return cid.replace("_", " ").capitalize()


def main():
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "recovered.json")
    out = Path(sys.argv[2] if len(sys.argv) > 2 else "seed-ontologia.json")
    D = json.loads(src.read_text())

    legacy_terms = {}          # chiave normalizzata -> nome originale
    for f in D["foods"]:
        legacy_terms.setdefault(norm(f["name"]), f["name"])
    for c in D["condiments"]:
        legacy_terms.setdefault(norm(c["name"]), c["name"])
    for _cid, items in D["condiment_groups"].items():
        for it in items:
            legacy_terms.setdefault(norm(it), it)
    for _pid, comps in D["courses"].items():
        for comp in comps:
            legacy_terms.setdefault(norm(comp["food"]), comp["food"])

    # frequenze reali nell'ontologia unificata
    freq_legacy = Counter()
    for m in D["meals"]:
        s = {norm(x) for x in m["food_keys"]} | {norm(c) for c in m["condiments"]}
        freq_legacy.update(s)

    coperti, doppi, voci = set(), [], []
    for cid, cat, gruppi, legacy in MAPPA:
        for l in legacy:
            k = norm(l)
            if k in coperti:
                doppi.append(l)
            coperti.add(k)
        sinonimi = sorted({legacy_terms.get(norm(l), l) for l in legacy})
        esposizioni = sum(freq_legacy.get(norm(l), 0) for l in legacy)
        voci.append({
            "id": cid,
            "nome": etichetta(cid),
            "categoria": cat,
            "gruppi": gruppi,
            "sinonimi": sinonimi,
            "terminiLegacy2020": sorted({norm(l) for l in legacy}),
            "esposizioni2020": esposizioni,
        })

    scoperti = sorted(k for k in legacy_terms if k not in coperti)

    voci.sort(key=lambda v: (v["categoria"], v["nome"]))
    payload = {
        "versione": 1,
        "origine": "Progetto-fondamenti-Nerelli (2020), anagrafiche Pasti + Condimenti unificate",
        "nota": ("Il campo `gruppi` contiene solo etichette di conoscenza comune "
                 "(lattosio, glutine, caffeina). Non e' un dato clinico e non deriva "
                 "da nessuna tabella FODMAP: quelle di Monash non sono utilizzabili "
                 "legalmente. Va trattato come ipotesi modificabile dall'utente."),
        "ingredienti": voci,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=1))

    print(f"termini del 2020 trovati : {len(legacy_terms)}")
    print(f"voci canoniche prodotte  : {len(voci)}")
    print(f"riduzione                : {len(legacy_terms)} -> {len(voci)}")
    print(f"termini non mappati      : {len(scoperti)}  {scoperti if scoperti else ''}")
    print(f"termini mappati due volte: {len(doppi)}  {doppi if doppi else ''}")
    print()
    print("categorie:", dict(sorted(Counter(v['categoria'] for v in voci).items())))
    con_gruppo = [v for v in voci if v["gruppi"]]
    print(f"voci con almeno un gruppo ipotizzato: {len(con_gruppo)}")
    print()
    top = sorted(voci, key=lambda v: -v["esposizioni2020"])[:20]
    print("le 20 voci canoniche piu' frequenti nel 2020:")
    for v in top:
        print(f"  {v['esposizioni2020']:3d}  {v['nome']:32s} [{v['categoria']}]")
    print()
    print(f"voci con >= 10 esposizioni: {sum(1 for v in voci if v['esposizioni2020']>=10)}")
    print(f"voci con >=  5 esposizioni: {sum(1 for v in voci if v['esposizioni2020']>=5)}")
    print(f"voci mai usate nel 2020   : {sum(1 for v in voci if v['esposizioni2020']==0)}")


if __name__ == "__main__":
    main()
