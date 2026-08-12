# Tratto

[![build](https://github.com/nerln/tratto/actions/workflows/build.yml/badge.svg)](https://github.com/nerln/tratto/actions/workflows/build.yml)

Diario intestinale e alimentare per macOS, iOS, Windows e Android. Registra in
tre tocchi, tiene tutto sul dispositivo, esporta in formati che un clinico può
aprire, e non nomina mai un alimento colpevole.

Il sito sta su [nerln.github.io/tratto](https://nerln.github.io/tratto/), i
binari fra le [release](https://github.com/nerln/tratto/releases).

Interfaccia in inglese, con l'italiano selezionabile dalle impostazioni e senza
riavviare l'app.

La fase 1 fa una cosa sola e la fa per intero: **registra**. Non mette in
relazione gli alimenti con i sintomi, e non lo farà. La fase 2 aggiunge l'unica
cosa che quella relazione la può davvero produrre: un **confronto programmato**,
con il piano congelato prima di iniziare.

## Da dove viene

L'obiettivo iniziale, nel 2020, era il più ovvio: tenere un diario di cibo e
funzione intestinale per 68 giorni e ricavarne quali alimenti facessero male. Il
risultato è stato che il diario non poteva dirlo, e la ragione stava nei dati e
non nei conti: gran parte delle giornate era registrata a metà, e gli alimenti
interessanti non erano mai stati mangiati abbastanza spesso, né abbastanza
separatamente, da poter essere distinti.

Da qui l'idea di Tratto. Un diario vale la pena di tenerlo, vale la pena di
tenerlo bene, e nel momento in cui indica un colpevole sta inventando. Quindi
questo registra per davvero e dichiara quello che vede e quello che non vede.

## Che cosa fa, in breve

- **Tre tocchi per un evento**: apri, scegli la forma fra sette disegni, salvi.
- **I pasti in lingua naturale**, dettati o scritti, riconosciuti contro un
  vocabolario chiuso di 142 ingredienti in inglese e italiano, e sempre
  correggibili a mano.
- **Registra l'assenza**: chiede delle fasce saltate e accetta «niente» come
  risposta, così una colazione vuota è vuota e non ignota.
- **Mostra i tuoi numeri**: copertura, distribuzione delle forme, andamento del
  dolore, quanto oscillano i dati da soli, quanto devono distare due giorni per
  smettere di somigliarsi. Mai una classifica di alimenti.
- **Un referto di una pagina** da portare a una visita.
- **Fase 2**: quando vuoi una risposta, imposta un confronto vero a blocchi
  alternati, e prima ti dice se può funzionare.

### Privacy, integrazioni, scale, prezzo

**Privacy.** Nessun server, nessun account, nessuna telemetria, nessuna
richiesta di rete fatta dall'app. Niente iCloud, sia perché le linee guida App
Store vietano i dati sanitari personali in iCloud, sia perché la sincronizzazione
è il punto in cui un'app locale smette di esserlo: fra Mac e telefono si passa
un file esplicito. Il riconoscimento dei pasti avviene sul dispositivo. L'app web
**non** è ospitata su `nerln.github.io`: un archivio sanitario in IndexedDB su
un'origine condivisa con altri progetti sarebbe leggibile da qualsiasi altra
pagina di quell'origine.

**Integrazioni.** Esportazione in bundle FHIR R4, tre CSV, JSON completo, e
referto PDF su macOS e iOS; reimportazione dal JSON. Le codifiche esterne
(SNOMED CT, LOINC) sono opzionali e spente di default, quella locale c'è sempre.
Tratto **non** scrive su Apple Health né su Health Connect, perché nessuna delle
due ha un tipo per questi dati e l'insieme dei tipi non è estendibile.

**Scale.** Sette livelli di forma con disegni ed etichette propri, nessuno
strumento proprietario nominato; dolore 0-10 nelle ultime 24 ore come esito
primario (LOINC 72514-3); fasce dei pasti invece di orari liberi. Ogni
esportazione dichiara quale scala ha prodotto i numeri. Nessun punteggio clinico
pubblicato viene calcolato (MDCG 2019-11).

**Prezzo.** Gratis su tutte e quattro le piattaforme, nessun abbonamento,
nessun livello a pagamento, nessun acquisto. Su iOS, senza account developer a
pagamento, una build fatta da sé va reinstallata ogni sette giorni.

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

Non per prudenza, ma perché su questi numeri la risposta non è distinguibile dal
caso. Tre ragioni, tutte misurate e non asserite:

- Un punteggio giornaliero finisce attribuito **a tutti** gli alimenti di quel
  giorno, e due cibi mangiati sempre insieme non si separano con nessun calcolo.
- Confrontare decine di alimenti senza correzione produce risultati
  «significativi» a comando, e quasi nessuno di quegli alimenti ha abbastanza
  esposizioni per reggere un confronto.
- Soprattutto: se solo **26 giornate su 68** hanno almeno tre pasti registrati,
  nelle altre l'alimentazione è in gran parte ignota. Il problema non è la
  statistica, è che i tre quarti delle giornate non sono osservate.

La conseguenza in codice è che dal diario osservazionale non esce mai una
relazione fra alimenti e sintomi, in nessuna schermata. L'unica relazione che
l'app produce viene dalla fase 2.

## Le costanti vengono da dati misurati, non da un manuale

Calcolate su 68 giorni di diario reale con `Strumenti/varianza.py`.

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
TrattoTests/  120 prove in 15 suite, fra cui quella che scrive il file d'oro
cross/        la versione TypeScript: nucleo condiviso, Electron per Windows,
              Capacitor per Android
docs/         il sito, servito da GitHub Pages
fixtures/     golden.json, il contratto fra le due implementazioni
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

## Windows e Android

Sotto `cross/` c'è una seconda implementazione in TypeScript, senza framework:
il nucleo statistico, il riconoscimento dei pasti, la copertura, il motore dei
confronti e l'esportazione. Da lì escono la build Electron per Windows e quella
Capacitor per Android.

```bash
cd cross
npm ci
npm test                                    # 70 asserzioni contro il file d'oro
npm run build                               # bundle web
npx electron-builder --win portable zip     # .exe portabile + zip
npx cap sync android && (cd android && ./gradlew assembleDebug)
```

### Il file d'oro

Due implementazioni della stessa statistica esatta divergono in silenzio. Per
questo la suite Swift **scrive** `fixtures/golden.json` (test dei segni,
Wilcoxon con ranghi pari merito, potenza, quantile normale, sequenze dei
blocchi, riconoscimento sull'ontologia vera) e la suite TypeScript deve
riprodurlo cifra per cifra. La CI rifà il file su macOS e fallisce se `git
diff` sul file non è vuoto: la deriva non passa inosservata.

L'oracolo dei test esatti non è `scipy`. Con i pari merito
`scipy.stats.wilcoxon(mode="exact")` usa la tabella senza pari merito e dà un
valore diverso; l'oracolo è l'enumerazione di tutte le 2<sup>n</sup>
assegnazioni di segno.

### Le due cose che ci sono costate un giro

**La WebView di Capacitor non registra alcun `DownloadListener`.** Verificato
leggendo i sessanta file Java del plugin, non la documentazione. Dentro l'app
Android un blob URL e un `<a download>` non producono nessun file e nessun
errore: l'esportazione passa dal plugin filesystem e poi dal foglio di
condivisione. L'importazione invece funziona da sola, perché
`onShowFileChooser` è implementato.

**La chiave di debug sta nel repository, di proposito.** Android non installa
APK non firmati, e lasciato a sé Gradle firma con `~/.android/debug.keystore`,
che ogni macchina genera per conto suo: la build di questo Mac e quella di un
runner avrebbero due identità diverse, e la seconda non si installerebbe sopra
la prima. `cross/android/tratto-debug.keystore` non protegge niente e non
vuole farlo; serve solo a rendere possibile un aggiornamento.

### Firma su Windows: nessuna, e non è una svista

Da metà 2024 un certificato EV non salta più SmartScreen, e Azure Artifact
Signing è aperto agli sviluppatori individuali soltanto di Stati Uniti e
Canada. Per un individuo italiano, fuori dallo Store, pagare non comprerebbe
nulla. La build è quindi non firmata e il sito lo dice.

## Il sito

`docs/` è servito da GitHub Pages su `main`. Tre file, nessuna richiesta a
terzi, nessun font remoto, nessuna analitica. Passa pa11y sullo standard
WCAG2AA senza rilievi. L'app web non è ospitata lì: un archivio sanitario in IndexedDB su
un'origine condivisa con altri progetti sarebbe leggibile da qualsiasi altra
pagina della stessa origine.

## Che cosa non è

Tratto non è un dispositivo medico, non formula diagnosi e non sostituisce il
parere di un medico. Non suggerisce di eliminare, ridurre o reintrodurre
alcunché. La decisione di togliere un alimento non appartiene a un'app scritta
dal paziente.
