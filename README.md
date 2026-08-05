# Tratto

Diario intestinale e alimentare per macOS e iOS. Riprende, sei anni dopo, il
progetto [Progetto-fondamenti-Nerelli](https://github.com/nerln/Progetto-fondamenti-Nerelli):
il diario che correlava cibo e funzione intestinale, tenuto dal 2 maggio all'8
luglio 2020 per l'esame di Fondamenti di Data Science.

Interfaccia in inglese, con l'italiano selezionabile dalle impostazioni e senza
riavviare l'app.

La fase 1 fa una cosa sola e la fa per intero: **registra**. Non mette in
relazione gli alimenti con i sintomi, e non lo farà. La fase 2 aggiunge l'unica
cosa che quella relazione la può davvero produrre: un **confronto programmato**,
con il piano congelato prima di iniziare.

## A chi serve

La domanda con cui il progetto è nato, «quali cibi mi fanno male», è quella a
cui un diario personale quasi mai riesce a rispondere. Le ragioni per tenerlo
comunque sono altre, e sono quelle per cui un diario intestinale viene chiesto
davvero:

- prima di una visita gastroenterologica, dove serve quello che è successo e non
  quello che si ricorda;
- dentro un percorso di eliminazione e reintroduzione seguito da un dietista,
  dove il diario è il registro del protocollo;
- quando il colpevole è già noto, per esempio una celiachia, e conta l'aderenza;
- prima e dopo una terapia, dove interessa il cambiamento e non la causa.

In tutti questi casi una registrazione fedele è tutto il lavoro. Il valore non è
l'inferenza: è che il dato porta un orario vero invece di essere ricostruito la
sera prima. Su questo la letteratura è netta: con il diario cartaceo l'aderenza
dichiarata è del 90% e quella reale dell'11%, contro il 94% del diario
elettronico (Stone 2002).

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

## La fase 2: confronti programmati

L'osservazione passiva non produce quello che servirebbe. Nel 2020 solo 19
ingredienti su 142 arrivavano a dieci esposizioni, e quelle esposizioni erano
quando capitava, insieme ad altri cibi, senza dose. Un confronto programmato
forza l'esposizione a un bersaglio scelto, in blocchi alternati.

**La struttura viene da protocolli pubblicati e citabili** (Whelan 2018;
Lomer 2023, CC BY): un bersaglio per volta, blocchi consecutivi, una pausa fra
l'uno e l'altro, nessuna reintroduzione stabile finché tutti i confronti non
sono chiusi.

**Le durate no.** In clinica il blocco è di 3 giorni; qui è più lungo, per due
ragioni indipendenti. L'autocorrelazione di questa persona è +0,51 a un giorno,
+0,16 a tre e +0,05 a quattro, quindi una pausa di 3 giorni lascia dentro l'eco
del blocco precedente. E nel challenge in cieco pubblicato i sintomi da lattosio
compaiono al terzo giorno, quindi un blocco di 3 giorni è troncato prima di
poterli vedere.

**Il numero che l'app mostra prima di lasciarti iniziare non è l'effetto minimo:
è la potenza.** Con sei coppie e ipotesi bilaterale il test richiede l'unanimità,
quindi la potenza è p⁶. Anche se il bersaglio peggiorasse davvero i sintomi in
otto coppie su dieci, la probabilità di arrivare a un risultato significativo è
del **26%**. Con cinque coppie o meno nessun risultato può essere significativo,
qualunque cosa succeda, e l'app lo dice invece di lasciartelo scoprire dopo due
mesi. Nove coppie sono la prima dimensione che tollera una sola discordanza.

**Il piano si congela.** Ipotesi, esito, regola di decisione e sequenza dei
blocchi entrano in un testo canonico di cui si calcola uno SHA-256. Se qualcosa
cambia dopo, l'analisi si rifiuta di girare. È l'unico modo per rendere
credibile una preregistrazione fatta da chi è insieme sperimentatore e soggetto.

**Non c'è un placebo, e viene detto.** Gli alimenti interi non si possono
accecare. Il blocco di confronto usa un ingrediente che non si sospetta: non
elimina l'aspettativa, le dà qualcosa contro cui essere misurata. Il motivo per
cui serve è un numero: nel challenge in cieco di Van den Houte il **glucosio di
controllo ha «scatenato» sintomi nel 26%** dei pazienti, più del sorbitolo.

**La statistica è esatta, non approssimata.** Test dei segni sulla binomiale e
Wilcoxon dei ranghi con segno, con la distribuzione nulla costruita per
permutazione dei segni sui ranghi *osservati*. Con gli ex aequo e con la
convenzione di Pratt questo non coincide con la tavola classica, e la tavola
sbaglia: `scipy.stats.wilcoxon(mode="exact")` usa la tavola e su quei casi dà un
valore diverso. L'oracolo dei test è l'enumerazione di tutti i 2ⁿ assegnamenti
di segno.

**I pareggi sono il problema numero uno.** Ogni differenza nulla toglie una
coppia: sei coppie con due pareggi diventano quattro, e il p minimo sale a
0,125. L'esperimento è morto prima di cominciare, e l'app mostra quel numero.

L'intervallo di Hodges-Lehmann viene mostrato con il livello di confidenza
**effettivo**: a sei coppie il 95% non esiste, esistono il 96,875% e il 93,75%.

## Lingua

L'app nasce in inglese; l'italiano è una traduzione completa (319 stringhe) che
si attiva dalle impostazioni senza riavviare. Il meccanismo è stato verificato
invece che assunto:

| meccanismo | cambia la lingua delle stringhe? |
|---|---|
| `.environment(\.locale)` in SwiftUI | **sì** |
| `String(localized:locale:)` | **no**, restituisce sempre quella del bundle |
| `LocalizedStringResource(_, locale:)` | **sì** |

Quindi le viste passano dall'ambiente e tutto il resto (referto, export, modelli)
da `LocalizedStringResource`. Le chiavi risolte a runtime, come le etichette
degli enum, non vengono estratte da Xcode e sono dichiarate a mano nel catalogo:
un test di regressione legge i `.strings` **compilati** nei due `lproj` e fallisce
se una chiave inglese non ha la sua traduzione, se un segnaposto è cambiato di
numero o di ordine, o se una stringa italiana è rimasta identica all'inglese.

L'export strutturato (CSV, JSON, FHIR) resta sempre in inglese: lo legge una
macchina, o un clinico che potrebbe non parlare la lingua di chi l'ha prodotto.
Il referto PDF invece segue la lingua scelta, perché lo legge una persona.

## Struttura

```
Tratto/
  App/        avvio, navigazione, notifiche, imbragatura di anteprima (solo DEBUG)
  Model/      entità SwiftData, scala della forma, codifiche
  Analisi/    statistica descrittiva, copertura, riepilogo, test esatti, motore dei confronti
  Parsing/    riconoscimento deterministico + suggeritore on-device
  Export/     CSV, JSON, FHIR
  Views/      schermate, disegni della scala, referto PDF
  Resources/  seed-ontologia.json (142 voci, bilingue), archivio-2020.json (sola lettura),
              Localizable.xcstrings (319 chiavi)
TrattoTests/  119 prove
Strumenti/    etl.py, ontologia.py, nomi_en.py, varianza.py, chiavi.py, traduci.py
dati/         recovered.json, l'originale normalizzato
```

## Le cinque schermate

1. **Adesso** — due bersagli grandi. Bagno: tre tocchi. Pasto: si detta, e le
   etichette riconosciute si correggono a mano.
2. **Giornata** — la cronologia, per rileggere e correggere.
3. **Raccolta** — copertura, distribuzione delle forme, andamento del dolore,
   quanto oscillano i numeri, quante volte hai mangiato che cosa. Un conteggio,
   mai una classifica.
4. **Confronti** — la fase 2: programmazione dei blocchi, congelamento del
   piano, e il quadro di potenza da leggere prima di impegnarsi.
5. **Esporta** — referto PDF di una pagina, tre CSV, JSON, bundle FHIR.

Dentro le impostazioni: la lingua, i pasti ricorrenti, i promemoria, la
schermata «A che cosa serve Tratto», e l'**Archivio 2020** in sola lettura.

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
