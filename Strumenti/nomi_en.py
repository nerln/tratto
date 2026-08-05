#!/usr/bin/env python3
"""
Aggiunge il nome inglese a ogni voce dell'ontologia e traduce le categorie.

I nomi italiani restano: sono l'origine del dato e servono comunque al
riconoscimento del testo dettato in italiano. Quello inglese si aggiunge
accanto, e l'app mostra l'uno o l'altro secondo la lingua scelta.

Dove un piatto non ha un equivalente inglese (gubana, erbazzone, frico,
canederli, piadina) si tiene il nome italiano con una glossa fra parentesi:
tradurli sarebbe inventare un cibo che non esiste.

Uso: python3 nomi_en.py <seed-ontologia.json>   (modifica il file sul posto)
"""
import json, sys
from pathlib import Path

CATEGORIE = {
    "Bevande": "Drinks",
    "Carne bianca": "Poultry",
    "Carne rossa": "Red meat",
    "Cereali": "Grains",
    "Condimenti": "Condiments",
    "Dolci": "Sweets",
    "Erbe e spezie": "Herbs and spices",
    "Formaggi": "Cheese",
    "Frutta": "Fruit",
    "Frutta secca": "Nuts",
    "Grassi": "Fats",
    "Latticini": "Dairy",
    "Legumi": "Legumes",
    "Pane": "Bread",
    "Pasta": "Pasta",
    "Pasta ripiena": "Filled pasta",
    "Pesce": "Fish and seafood",
    "Piatti composti": "Composite dishes",
    "Salumi": "Cured meats",
    "Semi": "Seeds",
    "Tuberi": "Tubers",
    "Uova": "Eggs",
    "Verdura": "Vegetables",
    "Aggiunti da me": "Added by me",
}

NOMI = {
    # cereali e derivati
    "pasta_di_grano": "Pasta", "pasta_integrale": "Wholewheat pasta",
    "pasta_di_semola": "Durum wheat pasta", "pasta_di_mais": "Corn pasta",
    "tortelli": "Tortelli (filled pasta)", "gnocchi_integrali": "Wholewheat gnocchi",
    "riso": "Rice", "riso_soffiato": "Puffed rice", "galletta_di_riso": "Rice cakes",
    "corn_flakes": "Corn flakes", "polenta": "Polenta",
    "pangrattato": "Breadcrumbs", "pangrattato_senza_glutine": "Gluten-free breadcrumbs",
    # pane
    "pane_di_semola": "Durum wheat bread", "pane_integrale": "Wholemeal bread",
    "pane_alle_noci": "Walnut bread", "pane_alle_olive": "Olive bread",
    "pane_senza_glutine": "Gluten-free bread", "pancarre": "Sliced white bread",
    "pancarre_integrale": "Sliced wholemeal bread",
    "pancarre_senza_glutine": "Gluten-free sliced bread",
    "focaccia": "Focaccia", "grissini": "Breadsticks",
    "piadina_senza_glutine": "Gluten-free flatbread",
    # frutta
    "mela": "Apple", "pera": "Pear", "banana": "Banana", "arancia": "Orange", "limone": "Lemon",
    # verdura
    "carota": "Carrot", "finocchio": "Fennel", "zucchina": "Courgette", "cipolla": "Onion",
    "pomodoro": "Tomato", "insalata": "Lettuce", "sedano": "Celery", "spinaci": "Spinach",
    "asparagi": "Asparagus", "carciofo": "Artichoke", "melanzana": "Aubergine",
    "peperone": "Bell pepper", "cavolo_cappuccio": "White cabbage", "funghi": "Mushrooms",
    "verdure_miste": "Mixed vegetables", "patata": "Potato",
    # legumi
    "ceci": "Chickpeas", "fagioli_cannellini": "Cannellini beans",
    # carne
    "pollo": "Chicken", "carne_trita": "Minced meat", "carne_a_pezzi": "Diced meat",
    "agnello": "Lamb", "salsiccia": "Sausage", "spiedini_di_maiale": "Pork skewers",
    # salumi
    "speck": "Speck", "salame": "Salami", "salame_piccante": "Spicy salami",
    "salame_d_oca": "Goose salami", "prosciutto_crudo": "Prosciutto crudo",
    "prosciutto_cotto": "Cooked ham", "mortadella": "Mortadella",
    "pancetta": "Pancetta", "wurstel": "Frankfurter",
    # pesce
    "merluzzo": "Cod", "baccala": "Salt cod", "salmone": "Salmon",
    "salmone_affumicato": "Smoked salmon", "tonno": "Tuna", "sgombro": "Mackerel",
    "acciughe": "Anchovies", "gamberetti": "Prawns", "frutti_di_mare": "Seafood",
    # uova
    "uovo": "Egg", "tuorlo": "Egg yolk",
    # latticini
    "latte_senza_lattosio": "Lactose-free milk", "yogurt": "Yoghurt", "panna": "Cream",
    "panna_senza_lattosio": "Lactose-free cream", "parmigiano": "Parmesan",
    "mozzarella": "Mozzarella", "formaggio_senza_lattosio": "Lactose-free cheese",
    # grassi e condimenti
    "olio_di_oliva": "Olive oil", "burro": "Butter", "olive_verdi": "Green olives",
    "olive_nere": "Black olives", "capperi": "Capers", "aceto_di_vino": "Wine vinegar",
    "salsa_di_soia": "Soy sauce", "salsa_di_pomodoro": "Tomato sauce",
    "pesto_genovese": "Basil pesto", "pesto_ricotta_noci": "Ricotta and walnut pesto",
    "marmellata": "Jam",
    # erbe e spezie
    "basilico": "Basil", "origano": "Oregano", "erba_cipollina": "Chives",
    "zenzero": "Ginger", "curry": "Curry", "zafferano": "Saffron",
    "pepe_nero": "Black pepper", "vaniglia": "Vanilla",
    # frutta secca e semi
    "pistacchio": "Pistachio", "arachidi": "Peanuts", "semi_di_sesamo": "Sesame seeds",
    # dolci
    "cioccolato_fondente": "Dark chocolate", "cioccolato_al_latte": "Milk chocolate",
    "crema_di_nocciole": "Hazelnut spread", "gelato": "Ice cream",
    "gelato_senza_lattosio": "Lactose-free ice cream", "budino": "Pudding",
    "torta_di_mele": "Apple cake", "torta_foresta_nera": "Black forest cake",
    "zuppa_inglese": "Zuppa inglese (trifle)", "gubana": "Gubana (Friulian sweet bread)",
    "krapfen": "Doughnut", "cornetto_alla_crema": "Custard croissant",
    "cantuccini_senza_glutine": "Gluten-free almond biscuits",
    # bevande
    "caffe": "Coffee", "caffe_d_orzo": "Barley coffee", "te_alla_pesca": "Peach iced tea",
    "tisana": "Herbal tea", "cioccolata_calda": "Hot chocolate", "coca_cola": "Coca-Cola",
    "latte_di_mandorla": "Almond milk",
    # piatti composti
    "pizza": "Pizza", "sushi": "Sushi", "hamburger": "Burger",
    "cotoletta": "Breaded cutlet", "involtini": "Meat roulades", "spezzatino": "Meat stew",
    "polpette_di_carne": "Meatballs",
    "polpette_di_carne_senza_glutine": "Gluten-free meatballs",
    "polpette_di_tonno": "Tuna balls", "canederli": "Canederli (bread dumplings)",
    "gnocchi_di_sauris": "Gnocchi di Sauris (ham dumplings)",
    "frico": "Frico (cheese and potato cake)", "erbazzone": "Erbazzone (spinach pie)",
    "rustico": "Savoury pastry", "panzerotto": "Panzerotto (fried turnover)",
    "empanada": "Empanada", "tortilla_di_patate": "Potato omelette",
    "rotolo_speck_formaggio": "Speck and cheese roll",
    "pollo_tikka_masala": "Chicken tikka masala", "patatine_fritte": "Chips",
}


def main():
    percorso = Path(sys.argv[1] if len(sys.argv) > 1 else "Tratto/Resources/seed-ontologia.json")
    d = json.loads(percorso.read_text())

    mancanti = [v["id"] for v in d["ingredienti"] if v["id"] not in NOMI]
    if mancanti:
        print("VOCI SENZA NOME INGLESE:", mancanti)
        sys.exit(1)

    cat_mancanti = sorted({v["categoria"] for v in d["ingredienti"]} - set(CATEGORIE))
    if cat_mancanti:
        print("CATEGORIE SENZA TRADUZIONE:", cat_mancanti)
        sys.exit(1)

    for v in d["ingredienti"]:
        v["nomeIt"] = v["nome"]
        v["nomeEn"] = NOMI[v["id"]]
        v["categoriaIt"] = v["categoria"]
        v["categoriaEn"] = CATEGORIE[v["categoria"]]
        del v["nome"]
        del v["categoria"]

    d["versione"] = 2
    d["nota"] = (
        "Il campo `gruppi` contiene solo etichette di conoscenza comune "
        "(lattosio, glutine, caffeina). Non e' un dato clinico e non deriva da "
        "nessuna tabella FODMAP: quelle di Monash non sono utilizzabili "
        "legalmente. Va trattato come ipotesi modificabile dall'utente. "
        "I nomi italiani restano perche' servono comunque al riconoscimento del "
        "testo dettato in italiano, qualunque sia la lingua dell'interfaccia."
    )
    percorso.write_text(json.dumps(d, ensure_ascii=False, indent=1))

    duplicati = len(d["ingredienti"]) - len({v["nomeEn"] for v in d["ingredienti"]})
    print(f"voci aggiornate    : {len(d['ingredienti'])}")
    print(f"categorie tradotte : {len(CATEGORIE) - 1}")
    print(f"nomi inglesi duplicati: {duplicati}")
    print(f"versione seed      : {d['versione']}")


if __name__ == "__main__":
    main()
