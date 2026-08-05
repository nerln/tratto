# Tratto

Diario intestinale e alimentare per macOS e iOS. Riprende, sei anni dopo, il
progetto [Progetto-fondamenti-Nerelli](https://github.com/nerln/Progetto-fondamenti-Nerelli):
il diario che correlava cibo e funzione intestinale, tenuto dal 2 maggio all'8
luglio 2020 per l'esame di Fondamenti di Data Science.

L'app fa una cosa sola e la fa per intero: **registra**. Non mette in relazione
gli alimenti con i sintomi, e non lo farà.

---

## Perché non calcola correlazioni

Il progetto del 2020 le calcolava, e il modo in cui lo faceva non reggeva.
Rileggendo il codice R e rimisurando i dati:

- Il punteggio giornaliero veniva attribuito **a tutti** gli alimenti mangiati
  quel giorno. Due cibi mangiati sempre insieme non si possono separare con
  nessun calcolo.
- Il punteggio veniva poi «validato» correlandolo con la consistenza media e il
  fastidio medio: **ma era calcolato a partire da quei due numeri**. La
  correlazione di Pearson 0,84 era il punteggio che correlava con sé stesso.
- 83 alimenti confrontati senza nessuna correzione per il numero dei confronti,
  e solo **7** di loro comparivano in almeno dieci pasti.
- Solo **26 giorni su 68** avevano almeno tre pasti registrati. Negli altri
  l'alimentazione era in gran parte ignota.

Quest'ultimo è il numero che conta. Il problema non era la statistica: era che
i tre quarti delle giornate non erano osservate.

## Che cosa è stato misurato prima di decidere

Non asserito: calcolato sui dati veri del 2020 (`Strumenti/varianza.py`).

| grandezza | valore | conseguenza sul progetto |
|---|---|---|
| deviazione standard della consistenza | 0,91 su scala 0-5 | l'esito **ha** varianza usabile |
| entropia normalizzata | 0,74 | la scala veniva usata, non era piatta |
| ICC (quota di varianza fra giorni) | 0,57 | il 43% del rumore sta *dentro* la giornata: la media giornaliera è giustificata |
| autocorrelazione a 1 giorno | +0,51 | i giorni consecutivi non sono indipendenti |
| autocorrelazione a 3 giorni | +0,16 | una pausa fra due condizioni deve durare almeno 3 giorni, **derivato** |
| effetto minimo rilevabile | 0,69 punti con 6 confronti da 5 giorni | un confronto è possibile, ma solo per effetti medio-grandi |
| coppie inseparabili | una sola (latte senza lattosio / riso soffiato) | la collinearità è molto minore del previsto: era la colazione |
| ingredienti con ≥ 10 esposizioni | 19 su 142 voci canoniche | l'insieme realmente analizzabile |

L'app ricalcola queste stesse grandezze sui dati nuovi, e mostra la
rilevabilità **solo** dopo 21 giorni di serie: prima, qualunque «servono N
giorni» sarebbe un numero inventato.

## Decisioni e loro motivo

**Nessuna scala proprietaria.** La scala clinica a sette livelli più nota è
materiale con copyright, con la titolarità per giunta contesa fra più soggetti.
Tratto usa sette disegni vettoriali propri e sette etichette scritte ex novo; la
parola «Bristol» non compare nell'interfaccia. All'esportazione il dato resta
comunque leggibile, con una nota che dice esplicitamente che non è quella scala.

**L'esito primario è il dolore, non la consistenza.** Non perché la consistenza
sia inutilizzabile (vedi la tabella sopra), ma perché il dolore su scala 0-10
nelle ultime 24 ore non è mai stato misurato nel 2020, è l'endpoint usato nei
trial, ed è l'unica variabile in gioco con un codice pubblico e libero:
LOINC 72514-3.

**Si registra l'assenza, non si insiste sulla presenza.** Nel 2020 la colazione
risultava annotata 25 volte su 59 giorni e lo spuntino del mattino una volta
sola. Non per pigrizia: un evento in bagno si ricorda, una colazione uguale a
tutte le altre no. Una fascia con risposta «niente» è un dato; una lasciata
vuota è un buco. Le notifiche hanno l'azione «Niente» diretta.

**Le due anagrafiche del 2020 diventano una.** «Alimenti» e «condimenti» erano
tabelle separate che si sovrapponevano: carota, tonno, parmigiano, finocchio,
salsiccia e uova comparivano in entrambe. Unificate: 150 termini → **142 voci
canoniche**, zero termini non mappati.

**Il modello suggerisce, non decide.** Misurato sul modello on-device di iOS 26
/ macOS 26: lasciato libero di produrre stringhe inventa voci fuori vocabolario
(2 su 4 frasi di prova); costretto da uno schema chiuso non inventa più nulla ma
restituisce liste vuote su 2 frasi su 3. Nessuna delle due modalità regge da
sola. Quindi l'estrazione è libera e la **decisione su cosa sia un ingrediente è
deterministica**, in codice ispezionabile e testato.

**Niente iCloud, niente CloudKit.** Le linee guida App Store vietano di
conservare informazioni sanitarie personali in iCloud. Store locale per
piattaforma, scambio fra Mac e telefono come file esplicito, che è anche
l'artefatto da consegnare.

**Nessun punteggio clinico pubblicato.** Calcolare un IBS-SSS o un indice di
gravità sposterebbe l'app oltre la soglia di dispositivo medico (MDCG 2019-11).
Registrare, archiviare, cercare, esportare e mostrare grafici resta sotto.

**Nessun classificatore da foto.** Non esiste niente di open source e
utilizzabile per le sette classi: il migliore risultato in letteratura è 81,7%
di accuratezza bilanciata con telecamera fissa, l'unico modello scaricabile è
binario e senza dataset documentato.

## Struttura

```
Tratto/
  App/        avvio, navigazione, notifiche, imbragatura di anteprima (solo DEBUG)
  Model/      entità SwiftData, scala della forma, codifiche
  Analisi/    statistica descrittiva, copertura, riepilogo   ← nessun test di ipotesi, per scelta
  Parsing/    riconoscimento deterministico + suggeritore on-device
  Export/     CSV, JSON, FHIR
  Views/      schermate, disegni della scala, referto PDF
  Resources/  seed-ontologia.json (142 voci), archivio-2020.json (sola lettura)
TrattoTests/  71 prove
Strumenti/    etl.py, ontologia.py, varianza.py — il recupero dei dati del 2020
dati/         recovered.json, l'originale normalizzato
```

## Le cinque schermate

1. **Adesso** — due bersagli grandi. Bagno: tre tocchi. Pasto: si detta, e le
   etichette riconosciute si correggono a mano.
2. **Giornata** — la cronologia, per rileggere e correggere.
3. **Raccolta** — copertura, distribuzione delle forme, andamento del dolore,
   quanto oscillano i numeri, quante volte hai mangiato che cosa. Un conteggio,
   mai una classifica.
4. **Archivio 2020** — il diario originale in sola lettura, con l'avviso che
   quella scala non è confrontabile con questa.
5. **Esporta** — referto PDF di una pagina, tre CSV, JSON, bundle FHIR.

## L'esportazione

Il PDF è il documento che ha senso portare a una visita: dati grezzi, la nota
che spiega quale scala si sta leggendo, nessuna conclusione.

Le codifiche esterne sono **spente di default**, e la codifica locale c'è
sempre. La ragione è che questo dominio è codificato in modo asimmetrico:

| dato | LOINC | SNOMED CT |
|---|---|---|
| forma delle feci | **non esiste** (l'unico «Bristol» in LOINC è una marca di sigarette) | 443172007 |
| dolore 0-10 | 72514-3 | non serve |
| frequenza evacuazioni | 80261-1 (ordinale, perde informazione) | 249521002 |

SNOMED CT non è libero in Italia, che non è fra i paesi membri. Per questo
`Observation.code` è un **array** di codifiche fin dalla prima versione dello
schema: senza quella scelta presa subito, un costo di licenza renderebbe
inesportabile un archivio già pieno.

## Compilare

```bash
xcodebuild -project Tratto.xcodeproj -scheme Tratto -destination 'platform=macOS,arch=arm64' test
```

Richiede Xcode 26 e prende di mira iOS 26 / macOS 26 (il riconoscimento dei
pasti usa il modello di sistema on-device).

Per gli screenshot e le anteprime, solo nelle build di sviluppo:

```bash
xcrun simctl launch booted dev.nerln.tratto --dati-esempio=45 --azzera --scheda=raccolta
```

## Che cosa non è

Tratto non è un dispositivo medico, non formula diagnosi e non sostituisce il
parere di un medico. Non suggerisce di eliminare, ridurre o reintrodurre
alcunché. La decisione di togliere un alimento non appartiene a un'app scritta
dal paziente.
