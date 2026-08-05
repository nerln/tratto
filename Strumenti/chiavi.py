#!/usr/bin/env python3
"""
Estrae dalle sorgenti Swift le stringhe che finiscono nel catalogo di
localizzazione, e le confronta con quelle gia' tradotte.

Non e' un parser di Swift: e' una serie di espressioni regolari sui punti in
cui, in questo progetto, una stringa e' localizzabile. Basta perche' le
convenzioni sono poche e costanti, e perche' l'errore che conta lo intercetta
comunque il test di regressione sul catalogo.

Uso:
  python3 chiavi.py estrai            elenca le chiavi trovate nel codice
  python3 chiavi.py confronta <cat>   dice quali mancano e quali sono orfane
"""
import json, re, sys
from pathlib import Path

SORGENTI = Path("Tratto")
CATALOGO = Path("Tratto/Resources/Localizable.xcstrings")

# I punti in cui una stringa letterale viene interpretata come chiave.
SCHEMI = [
    r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]',
    r'LocalizedStringKey\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'Label\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]',
    r'Section\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'Picker\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'Toggle\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'Stepper\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'TextField\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'DatePicker\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    r'LabeledContent\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]',
    r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'\.searchable\(text:[^)]*?prompt:\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'String\(localized:\s*"((?:[^"\\]|\\.)*)"',
    r'\.alert\(\s*"((?:[^"\\]|\\.)*)"\s*,',
    # le chiavi dichiarate esplicitamente nei modelli
    r'case\s+\.\w+:\s*"((?:[^"\\]|\\.)*)"',
    r'^\s*"((?:[^"\\]|\\.)*)"$',
]

# Stringhe che non sono testo per l'utente anche se compaiono nei punti sopra.
ESCLUSE = re.compile(
    r'^(|—|\d+|[a-z]+\.[a-z.]+|[a-z_]+|[A-Za-z0-9_]+\.(json|lproj)|'
    r'https?://.*|Tratto|en|it|\{score\}|.*%\d+\$@.*)$'
)


def letterali():
    trovate = {}
    for f in sorted(SORGENTI.rglob("*.swift")):
        testo = f.read_text(encoding="utf-8")
        # via i commenti di documentazione, che contengono virgolette
        testo = re.sub(r'^\s*///.*$', '', testo, flags=re.M)
        testo = re.sub(r'^\s*//(?!/).*$', '', testo, flags=re.M)
        for schema in SCHEMI:
            for m in re.finditer(schema, testo, flags=re.M):
                s = m.group(1)
                if not s or ESCLUSE.match(s):
                    continue
                # le stringhe che contengono interpolazione diventano chiavi con %@
                trovate.setdefault(s, set()).add(f.name)
    return trovate


def normalizza_interpolazione(s):
    """`\\(x)` diventa `%@` come fa xcstringstool."""
    return re.sub(r'\\\([^)]*\)', '%@', s)


def carica_catalogo():
    if not CATALOGO.exists():
        return {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    return json.loads(CATALOGO.read_text())


def main():
    comando = sys.argv[1] if len(sys.argv) > 1 else "estrai"
    trovate = letterali()
    chiavi = sorted(trovate)

    if comando == "estrai":
        for c in chiavi:
            print(f"{c}\t\t[{','.join(sorted(trovate[c]))}]")
        print(f"\n-- {len(chiavi)} chiavi", file=sys.stderr)
        return

    if comando == "confronta":
        cat = carica_catalogo()
        presenti = set(cat["strings"])
        mancanti = [c for c in chiavi if c not in presenti]
        orfane = sorted(presenti - set(chiavi))
        senza_it = sorted(
            k for k, v in cat["strings"].items()
            if not v.get("localizations", {}).get("it", {}).get("stringUnit", {}).get("value"))
        print(f"chiavi nel codice   : {len(chiavi)}")
        print(f"chiavi nel catalogo : {len(presenti)}")
        print(f"mancanti nel catalogo: {len(mancanti)}")
        for m in mancanti:
            print("   +", m)
        print(f"orfane nel catalogo  : {len(orfane)}")
        for o in orfane[:20]:
            print("   -", o)
        print(f"senza traduzione it  : {len(senza_it)}")
        for s in senza_it[:20]:
            print("   !", s)
        sys.exit(1 if (mancanti or senza_it) else 0)


if __name__ == "__main__":
    main()
