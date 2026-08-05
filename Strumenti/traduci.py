#!/usr/bin/env python3
"""
Riempie la colonna italiana del catalogo di stringhe.

Le chiavi non si scrivono a mano: le estrae Xcode dai .stringsdata e le
sincronizza `xcstringstool sync`. Qui si aggiungono solo le traduzioni, con un
controllo che i segnaposto (%@ e %lld) restino gli stessi e nello stesso
ordine: un segnaposto perso non fa fallire il build, fa comparire una riga
sbagliata a schermo mesi dopo.

Uso: python3 traduci.py [percorso-catalogo]
"""
import json, re, sys
from pathlib import Path

IT = {
 "%@ Recognition still works by matching your text against the catalogue.":
   "%@ Il riconoscimento funziona lo stesso, confrontando quello che scrivi con il catalogo.",
 "%@ vs %@": "%@ contro %@",
 "from %@ to %@": "dal %@ al %@",
 "%lld": "%lld",
 "%lld comparisons of %lld days": "%lld confronti da %lld giorni",
 "%lld days": "%lld giorni",
 "%lld days of gap": "%lld giorni di pausa",
 "%lld days per block": "%lld giorni per blocco",
 "%lld of %lld": "%lld su %lld",
 "%lld of %lld pairs complete": "%lld coppie su %lld completate",
 "%lld pairs of %lld days": "%lld coppie da %lld giorni",
 "%lld pairs of blocks": "%lld coppie di blocchi",
 "%lld pairs were lost because one of the two blocks has no usable days.":
   "%lld coppie sono andate perse perché uno dei due blocchi non ha giorni utilizzabili.",
 "0 means no pain at all, 10 the worst you can imagine.":
   "0 vuol dire nessun dolore, 10 il peggiore che riesci a immaginare.",
 "0 was the worst value and 5 the best. Three quarters of the observations sit on two adjacent levels: the scale was used little more than halfway.":
   "0 era il valore peggiore e 5 il migliore. Tre quarti delle osservazioni stanno su due livelli vicini: la scala veniva usata poco più che a metà.",
 "2020 archive": "Archivio 2020",
 "A bundle with one observation per event. Every code always carries the local coding.":
   "Un bundle con una osservazione per evento. Ogni codice porta sempre la codifica locale.",
 "A day with nothing in it stays a day with nothing in it: it does not count as observed.":
   "Un giorno senza niente resta un giorno senza niente: non viene contato come osservato.",
 "A diary records what happens. A comparison makes something happen on purpose, and that is a different kind of evidence.":
   "Un diario registra quello che succede. Un confronto fa succedere qualcosa apposta, ed è una prova di natura diversa.",
 "A one-sided hypothesis is easier to confirm, and that is exactly why it has to be chosen now and frozen. Choosing it after seeing the data is the shortcut that invalidates everything.":
   "Un'ipotesi unilaterale è più facile da confermare, ed è esattamente per questo che va scelta adesso e congelata. Sceglierla dopo aver visto i dati è la scorciatoia che invalida tutto.",
 "A personal diary produces too few repetitions. Testing dozens of foods at once makes chance findings almost certain.":
   "Un diario personale produce troppe poche ripetizioni. Provarne decine insieme rende quasi certo che qualcosa risulti positivo per caso.",
 "Abdominal pain, worst in the last 24 hours (0-10)":
   "Dolore addominale, il peggiore nelle ultime 24 ore (0-10)",
 "Add SNOMED CT and LOINC to the export": "Aggiungi SNOMED CT e LOINC all'esportazione",
 "An app that named a culprit anyway would not be more useful. It would be confidently wrong, and it might take a food away from you for years.":
   "Un'app che indicasse comunque un colpevole non sarebbe più utile. Sbaglierebbe con sicurezza, e potrebbe toglierti un alimento per anni.",
 "Archive not available.": "Archivio non disponibile.",
 "Asks one question a day: the worst abdominal pain in the last 24 hours.":
   "Fa una domanda al giorno: il peggior dolore addominale nelle ultime 24 ore.",
 "At %lld pairs a single pair going the other way ends the comparison without a result. The first size that tolerates one disagreement is %lld pairs.":
   "Con %lld coppie basta che una vada nella direzione opposta perché il confronto finisca senza risultato. La prima dimensione che tollera una discordanza è di %lld coppie.",
 "At least %lld days with pain recorded are needed to estimate how much it swings by itself. So far there are %lld.":
   "Servono almeno %lld giorni con il dolore segnato per stimare quanto oscilla da solo. Finora sono %lld.",
 "Bathroom": "Bagno",
 "Before a gastroenterology appointment, when the clinician needs to see what actually happens rather than what you remember.":
   "Prima di una visita gastroenterologica, quando il medico ha bisogno di vedere cosa succede davvero e non cosa ricordi.",
 "Before and after a treatment or a procedure, where the point is the change over time, not the cause.":
   "Prima e dopo una terapia o un intervento, dove quello che conta è il cambiamento nel tempo e non la causa.",
 "Before you commit, the next screen tells you how likely this is to find anything. Usually it is less than people expect.":
   "Prima di impegnarti, la schermata successiva ti dice quante probabilità ci sono di trovare qualcosa. Di solito sono meno di quanto ci si aspetti.",
 "Below 70%, what was eaten on most days is not known.":
   "Sotto il 70%, quello che hai mangiato nella maggior parte delle giornate non è noto.",
 "Bloating": "Gonfiore",
 "Blocks": "Blocchi",
 "Blood in your stool is something to show a doctor, even if it happens only once and even if you already have an explanation. Tratto just records it.":
   "Il sangue nelle feci è una cosa da far vedere a un medico, anche se succede una volta sola e anche se hai già una spiegazione. Tratto lo annota e basta.",
 "Bowel and food diary": "Diario intestinale e alimentare",
 "Bowel movements per day (mean)": "Evacuazioni al giorno (media)",
 "Can't recall": "Non ricordo",
 "Cancel": "Annulla",
 "Catalogue": "Catalogo",
 "Choose…": "Scegli…",
 "Close": "Chiudi",
 "Coffees: %lld": "Caffè: %lld",
 "Collected": "Raccolta",
 "Compared against": "Confrontato con",
 "Comparisons": "Confronti",
 "Complete days": "Giorni completi",
 "Completeness of the food diary": "Completezza del diario alimentare",
 "Computed on the swing measured in your own data, not on values taken from elsewhere. It is the most optimistic estimate possible: it assumes the periods are independent of each other and that you record every day.":
   "Calcolato sull'oscillazione misurata nei tuoi dati, non su valori presi altrove. È la stima più ottimistica possibile: dà per scontato che i periodi siano indipendenti fra loro e che tu registri tutti i giorni.",
 "Consistency, the 0-5 scale of 2020": "Consistenza, la scala 0-5 del 2020",
 "Could not finish starting up": "Avvio non completato",
 "Could not write the files: %@": "Non sono riuscito a scrivere i file: %@",
 "Coverage": "Copertura",
 "Coverage over the last 7 days is %@. Below 70%% a period is not analysable, because most days are not observed but only partly known.":
   "Negli ultimi 7 giorni la copertura è %@. Sotto il 70%% un periodo non è analizzabile, perché la maggior parte delle giornate non è osservata ma solo in parte nota.",
 "Data Science coursework, May–July 2020": "Progetto di Fondamenti di Data Science, maggio–luglio 2020",
 "Day": "Giornata",
 "Days with at least one bowel movement outside the middle range (1-2 or 6-7): %lld of %lld.":
   "Giornate con almeno un'evacuazione fuori dall'intervallo centrale (1-2 o 6-7): %lld su %lld.",
 "Days with at least one bowel movement outside the middle range: %lld of %lld observed.":
   "Giornate con almeno un'evacuazione fuori dall'intervallo centrale: %lld su %lld osservate.",
 "Days with entries": "Giorni con registrazioni",
 "Days with the entry filled in": "Giorni con la voce compilata",
 "Difference": "Differenza",
 "Discomfort before a bowel movement, the 0-5 scale of 2020":
   "Fastidio prima dell'evacuazione, la scala 0-5 del 2020",
 "Distance": "Distanza",
 "Distribution of stool form": "Distribuzione della forma delle feci",
 "Done": "Fatto",
 "During a structured elimination and reintroduction plan run with a dietitian, where the diary is the record of the protocol.":
   "Durante un percorso di eliminazione e reintroduzione seguito da un dietista, dove il diario è il registro del protocollo.",
 "Each bar is one pair: the target block minus the block it was compared against. Bars all on the same side is what the test is looking for.":
   "Ogni barra è una coppia: il blocco bersaglio meno il blocco di confronto. Barre tutte dallo stesso lato sono quello che il test sta cercando.",
 "Edit": "Modifica",
 "Edit meal": "Modifica pasto",
 "Edit today's pain": "Modifica il dolore di oggi",
 "Eighty-three foods were compared with no correction for the number of comparisons, and only seven of them appeared in at least ten meals.":
   "Ottantatré alimenti venivano confrontati senza nessuna correzione per il numero dei confronti, e solo sette di loro comparivano in almeno dieci pasti.",
 "Estimates of what could be detected only appear once there is enough data to compute them. Before that, any «you need N days» would be made up.":
   "Le stime su cosa si potrebbe vedere compaiono solo quando ci sono abbastanza dati per calcolarle. Prima, qualunque «servono N giorni» sarebbe inventato.",
 "Evening question at %lld:00": "Domanda della sera alle %lld:00",
 "Events, meals expanded one row per ingredient, and a daily file with outcomes, context and coverage. This is the road to R.":
   "Eventi, pasti espansi una riga per ingrediente, e un file giornaliero con esiti, contesto e copertura. È la strada verso R.",
 "Every reminder carries a «Nothing» action: one tap and a skipped slot becomes data instead of a hole.":
   "Ogni promemoria porta con sé l'azione «Niente»: un tocco e una fascia saltata diventa un dato invece di un buco.",
 "Everything, for backup and for moving data between Mac and phone as a file: there is no automatic sync.":
   "Tutto, per il backup e per passare i dati fra Mac e telefono come file: non c'è nessuna sincronizzazione automatica.",
 "Exact p": "p esatto",
 "Export": "Esporta",
 "Exports a one-page report for an appointment, plus CSV, JSON and FHIR.":
   "Esporta un referto di una pagina per la visita, più CSV, JSON e FHIR.",
 "External codings": "Codifiche esterne",
 "FHIR": "FHIR",
 "Files ready": "File pronti",
 "Finding the culprit is not the only reason to keep one. In most of the situations where a bowel diary is asked for, the question is different.":
   "Trovare il colpevole non è l'unico motivo per tenerne uno. Nella maggior parte delle situazioni in cui un diario intestinale viene richiesto, la domanda è un'altra.",
 "Fingerprint": "Impronta",
 "Follow the system": "Segui il sistema",
 "Foods eaten together cannot be told apart. If rice and olive oil almost always appear in the same meal, no calculation can separate them.":
   "I cibi mangiati insieme non si possono distinguere. Se riso e olio compaiono quasi sempre nello stesso pasto, nessun calcolo riesce a separarli.",
 "Form": "Forma",
 "Freeze and start": "Congela e inizia",
 "From 0 to 10": "Da 0 a 10",
 "From catalogue": "Dal catalogo",
 "Frozen on": "Congelato il",
 "Generate the files": "Genera i file",
 "Generating…": "Genero…",
 "Here 0 was the best value: the two scales of 2020 ran in opposite directions.":
   "Qui 0 era il valore migliore: le due scale del 2020 andavano in direzioni opposte.",
 "Hours of sleep": "Ore di sonno",
 "How large an effect would have to be to show up":
   "Quanto dovrebbe essere grande un effetto per potersi vedere",
 "How much the numbers move on their own": "Quanto oscillano i numeri da soli",
 "How often you ate what": "Quante volte hai mangiato che cosa",
 "How the day went": "Com'è andata la giornata",
 "Hypothesis": "Ipotesi",
 "I drank alcohol": "Ho bevuto alcol",
 "I exercised": "Ho fatto attività fisica",
 "I have read the numbers above": "Ho letto i numeri qui sopra",
 "I noticed blood": "Ho notato del sangue",
 "If the target really did affect you…": "Se il bersaglio ti riguardasse davvero…",
 "In all of these, a faithful record is the whole job. Tratto is built to do that job well and to stop there.":
   "In tutti questi casi, una registrazione fedele è tutto il lavoro. Tratto è fatta per farlo bene e fermarsi lì.",
 "In blinded challenges an inert substance triggered symptoms in about a quarter of patients. A single open test is wrong roughly one time in four.":
   "Nei confronti in cieco una sostanza inerte ha scatenato sintomi in circa un quarto dei pazienti. Una prova singola e in chiaro sbaglia grosso modo una volta su quattro.",
 "In numbers": "In cifre",
 "Ingredients": "Ingredienti",
 "Interval": "Intervallo",
 "JSON": "JSON",
 "Knowing that you ate nothing is data. A slot left blank is not.":
   "Sapere che non hai mangiato è un dato. Una fascia lasciata vuota, no.",
 "Language": "Lingua",
 "Level": "Livello",
 "Meal": "Pasto",
 "Meal slot": "Fascia",
 "Mean": "Media",
 "Mean coverage of the expected slots (breakfast, lunch, dinner) over the last 7 days: %@.":
   "Copertura media delle fasce attese (colazione, pranzo, cena) negli ultimi 7 giorni: %@.",
 "Median": "Mediana",
 "Median %@, typical swing ±%@ points over %lld days.":
   "Mediana %@, oscillazione tipica ±%@ punti su %lld giorni.",
 "Minimum and maximum": "Minimo e massimo",
 "Nearby days still resemble each other too much to be treated as independent observations.":
   "I giorni vicini si somigliano ancora troppo perché si possano trattare come osservazioni indipendenti.",
 "New comparison": "Nuovo confronto",
 "No meals recorded yet.": "Ancora nessun pasto registrato.",
 "Not all the pairs are finished. Looking at the result now and deciding whether to go on would break the test: the exact p is only valid if the number of pairs was fixed in advance.":
   "Non tutte le coppie sono finite. Guardare il risultato adesso e decidere se andare avanti romperebbe il test: il p esatto vale solo se il numero di coppie era fissato in partenza.",
 "Not in the catalogue": "Non sono nel catalogo",
 "Note on the scales": "Nota sulle scale",
 "Notes": "Note",
 "Nothing": "Niente",
 "Nothing here separates the target from what it was compared against. On a comparison this size that is the most common outcome, and it is a legitimate one: it means you can stop wondering about this ingredient for now.":
   "Qui non c'è niente che separi il bersaglio da quello con cui è stato confrontato. Su un confronto di questa dimensione è l'esito più comune, ed è un esito legittimo: vuol dire che per ora su questo ingrediente puoi smettere di interrogarti.",
 "Nothing recorded on this day.": "Nessuna registrazione in questo giorno.",
 "Nothing to show yet. Record your first event or your first meal.":
   "Non c'è ancora niente da mostrare. Registra il primo evento o il primo pasto.",
 "Notifications are turned off in system settings, so the reminders will not appear.":
   "Le notifiche sono disattivate nelle impostazioni di sistema, quindi i promemoria non compariranno.",
 "Now": "Adesso",
 "OK": "Va bene",
 "Of the variation in stool form, %@ sits between different days and the rest between bowel movements on the same day.":
   "Della variabilità della forma delle feci, %@ sta fra giorni diversi e il resto fra evacuazioni dello stesso giorno.",
 "Off by default. Stool form has a SNOMED CT concept but no LOINC code at all (the only «Bristol» in LOINC is a cigarette brand); pain from 0 to 10 does have a public LOINC code. SNOMED CT, however, is not free in Italy, which is not a member country: this is why the local coding is always there and the external ones are added only if you want them.":
   "Spento di default. La forma delle feci ha un concetto SNOMED CT ma nessun codice LOINC (l'unico «Bristol» presente in LOINC è una marca di sigarette); il dolore da 0 a 10 ha invece un codice LOINC pubblico. SNOMED CT però non è libero in Italia, che non è fra i paesi membri: per questo la codifica locale c'è sempre e quelle esterne si aggiungono solo se le vuoi.",
 "One page: period covered, how many bowel movements, how the forms are distributed, how pain went, and the note that says which scale was used. No conclusions: this is the document to bring to an appointment.":
   "Una pagina sola: periodo coperto, quante evacuazioni, come si distribuiscono le forme, l'andamento del dolore, e la nota che dice quale scala è stata usata. Nessuna conclusione: è il documento da portare a una visita.",
 "Only 26 days out of 68 had at least three meals recorded. On the rest, what was eaten was largely unknown.":
   "Solo 26 giorni su 68 avevano almeno tre pasti registrati. Negli altri, quello che era stato mangiato era in gran parte ignoto.",
 "Optional": "Facoltativo",
 "Outcome": "Esito",
 "Over 59 days, breakfast appears 25 times and the morning snack once. That is not carelessness: a trip to the bathroom is memorable, a breakfast identical to every other one is not. It is why today you can answer «nothing» with one tap.":
   "Su 59 giorni, la colazione compare 25 volte e lo spuntino del mattino una sola. Non è disattenzione: un evento in bagno si ricorda, una colazione uguale a tutte le altre no. È il motivo per cui oggi si può rispondere «niente» con un tocco.",
 "PDF report": "Referto PDF",
 "Pain": "Dolore",
 "Pain at the time": "Dolore in quel momento",
 "Pain is collected on a self-reported 0-10 numeric scale, once a day.":
   "Il dolore è raccolto su scala numerica 0-10 auto-riferita, una volta al giorno.",
 "Pain, day by day": "Dolore, giorno per giorno",
 "Pair": "Coppia",
 "Pair by pair": "Coppia per coppia",
 "Pairs that must agree": "Coppie che devono concordare",
 "Pairs used": "Coppie usate",
 "Period observed: %@ to %@": "Periodo osservato: dal %@ al %@",
 "Plan a comparison": "Programma un confronto",
 "Produced by Tratto, a diary kept by the patient. Data not verified by a third party.":
   "Prodotto da Tratto, diario compilato dal paziente. Dati non verificati da terzi.",
 "Recognise": "Riconosci",
 "Record today's pain": "Segna il dolore di oggi",
 "Records bowel movements in three taps, with their time, form, and optionally urgency and pain.":
   "Registra le evacuazioni in tre tocchi, con ora, forma e, se vuoi, urgenza e dolore.",
 "Records meals as ingredients, dictated or typed, and records the slots where you ate nothing.":
   "Registra i pasti come ingredienti, dettati o scritti, e registra le fasce in cui non hai mangiato.",
 "Remind me during the day": "Ricordamelo durante la giornata",
 "Reminders": "Promemoria",
 "Remove": "Togli",
 "Result": "Risultato",
 "Save": "Salva",
 "Search an ingredient": "Cerca un ingrediente",
 "Settings": "Impostazioni",
 "Shape of the plan": "Forma del piano",
 "Shows how complete the diary is, how the numbers are distributed, and how much they move on their own.":
   "Mostra quanto è completo il diario, come si distribuiscono i numeri e quanto oscillano da soli.",
 "Similarity": "Somiglianza",
 "Slot": "Fascia",
 "Smallest p you can reach": "p più piccolo raggiungibile",
 "So far stool form clusters on the same few values: with this little variety, an effect would have little room to show itself.":
   "Finora la forma delle feci si concentra quasi sempre sugli stessi valori: con così poca varietà, un effetto avrebbe poco spazio per manifestarsi.",
 "Still open today": "Fasce ancora aperte oggi",
 "Stool form": "Forma delle feci",
 "Stool form uses its whole range.": "La forma delle feci usa bene tutta la sua scala.",
 "Stool form uses part of its range.": "La forma delle feci usa una parte dei suoi livelli.",
 "Stress": "Stress",
 "Symptoms move a lot on their own. Sleep, stress, coffee and the working week shift the numbers as much as food does.":
   "I sintomi oscillano molto da soli. Sonno, stress, caffè e il ritmo della settimana muovono i numeri quanto il cibo.",
 "Tap to add them to your catalogue. Whatever you skip still stays in the text of the meal.":
   "Tocca per aggiungerli al tuo catalogo. Quello che non aggiungi resta comunque scritto nel testo del pasto.",
 "Target": "Bersaglio",
 "The analysis is not shown because the plan changed after it was frozen.":
   "L'analisi non viene mostrata perché il piano è cambiato dopo essere stato congelato.",
 "The app is written in English. Italian is a translation, and the change takes effect right away.":
   "L'app è scritta in inglese. L'italiano è una traduzione, e il cambio ha effetto subito.",
 "The daily score was assigned to every food eaten that day. Two foods always eaten together cannot be told apart, by any calculation.":
   "Il punteggio giornaliero veniva assegnato a tutti gli alimenti mangiati quel giorno. Due cibi mangiati sempre insieme non si possono distinguere, con nessun calcolo.",
 "The first %lld day of each block is left out of the calculation, to drop what carried over from the block before. It changes nothing in what you do.":
   "Il primo %lld giorno di ogni blocco resta fuori dal calcolo, per togliere quello che si trascina dal blocco precedente. Non cambia niente in quello che fai.",
 "The frozen plan": "Il piano congelato",
 "The interval is at %@, not at 95%%: with this many pairs 95%% is not one of the levels that exist.":
   "L'intervallo è al %@, non al 95%%: con questo numero di coppie il 95%% non è fra i livelli che esistono.",
 "The pairs lean the same way often enough that chance alone is an unlikely explanation. That is not the same as proof, and one comparison is not a diagnosis: an inert substance triggers symptoms in about a quarter of people. Repeat it before you act on it, and take it to a clinician.":
   "Le coppie pendono dalla stessa parte abbastanza spesso da rendere il caso una spiegazione poco probabile. Non è la stessa cosa di una prova, e un confronto solo non è una diagnosi: una sostanza inerte scatena sintomi in circa un quarto delle persone. Ripetilo prima di agire, e portalo a un medico.",
 "The plan is frozen before you start: the hypothesis, the outcome and the decision rule are fingerprinted, and the analysis refuses to run if any of them changed afterwards.":
   "Il piano viene congelato prima di iniziare: ipotesi, esito e regola di decisione ricevono un'impronta, e l'analisi si rifiuta di girare se uno di questi è cambiato dopo.",
 "The plan no longer matches the fingerprint taken when it was frozen. The analysis will not run: a comparison whose rules changed along the way cannot be read as if they had not.":
   "Il piano non corrisponde più all'impronta presa quando è stato congelato. L'analisi non viene eseguita: un confronto le cui regole sono cambiate per strada non si può leggere come se non lo fossero.",
 "The question mark marks entries matched by similarity: check them.":
   "Il punto interrogativo segna le voci riconosciute per somiglianza: controllale.",
 "The score was then «validated» by correlating it with mean consistency and mean discomfort. But it was computed from those two numbers: the correlation of 0.84 was the score correlating with itself.":
   "Il punteggio veniva poi «validato» correlandolo con la consistenza media e il fastidio medio. Ma era calcolato proprio a partire da quei due numeri: la correlazione di 0,84 era il punteggio che correlava con sé stesso.",
 "The structure follows published reintroduction protocols. The block lengths do not: they come from how much your own numbers carry over from one day to the next.":
   "La struttura segue i protocolli di reintroduzione pubblicati. Le durate dei blocchi no: vengono da quanto i tuoi numeri si trascinano da un giorno all'altro.",
 "The two lists were kept separate but overlapped: carrot, tuna, parmesan, fennel, sausage and eggs appeared in both. In today's catalogue they are a single entry.":
   "Le due anagrafiche erano separate ma si sovrapponevano: carota, tonno, parmigiano, finocchio, salsiccia e uova comparivano in tutte e due. Nel catalogo di oggi sono una voce sola.",
 "These are the chances of ending up with a significant result. They are low because a comparison this short needs almost every pair to agree.":
   "Sono le probabilità di arrivare a un risultato significativo. Sono basse perché un confronto così corto ha bisogno che quasi tutte le coppie concordino.",
 "These entries are not here to explain your symptoms. They are here to record what else was going on, because in a diary kept by one person sleep, stress and coffee move the numbers as much as food does.":
   "Queste voci non servono a spiegare i sintomi. Servono a sapere che cos'altro stava succedendo, perché in un diario di una persona sola sonno, stress e caffè muovono i numeri quanto il cibo.",
 "These numbers use different scales from the ones in use now and are not comparable. «Consistency» ran from 0 to 5 with 0 as the worst value and rose monotonically: it is not the seven-level scale used today, whose best value sits in the middle. It is not converted, it enters no calculation, and it is never added to new data. The period also falls in the months right after lockdown, with hours, diet and stress that are hard to repeat.":
   "Questi dati usano scale diverse da quelle di oggi e non sono confrontabili. La «consistenza» va da 0 a 5 con 0 come valore peggiore e cresce in modo monotono: non è la scala a sette livelli usata adesso, che ha l'ottimo al centro. Non viene convertita, non entra in nessun calcolo e non si somma ai dati nuovi. Il periodo cade inoltre nei mesi successivi al lockdown, con orari, dieta e stress difficilmente ripetibili.",
 "They are in the app's temporary folder: share them or save them wherever you like.":
   "Sono nella cartella temporanea dell'app: condividili o salvali dove vuoi.",
 "This comparison could not have reached significance with the pairs it has, so the result says nothing either way.":
   "Questo confronto non avrebbe potuto raggiungere la significatività con le coppie che ha, quindi il risultato non dice niente in nessuna direzione.",
 "This document reports only what was recorded. It contains no correlations between foods and symptoms, makes no diagnostic hypotheses, and is not produced by a medical device.":
   "Questo documento riporta soltanto quello che è stato registrato. Non contiene correlazioni fra alimenti e sintomi, non formula ipotesi diagnostiche e non è prodotto da un dispositivo medico.",
 "This is a count, not a ranking: none of these entries is put in relation with how you felt.":
   "È un conteggio, non una classifica: nessuna di queste voci è messa in relazione con come è andata.",
 "Three CSV files": "Tre file CSV",
 "Ties": "Pareggi",
 "Time": "Ora",
 "Times": "Volte",
 "Today": "Oggi",
 "Total bowel movements": "Evacuazioni totali",
 "Total length": "Durata totale",
 "Tratto": "Tratto",
 "Tratto lays out alternating blocks of days, with a gap between them, and randomises the order inside each pair.":
   "Tratto dispone blocchi di giorni alternati, con una pausa fra l'uno e l'altro, e sorteggia l'ordine dentro ogni coppia.",
 "Tratto never tells you that a food is causing your symptoms.":
   "Tratto non ti dirà mai che un alimento è la causa dei tuoi sintomi.",
 "Tratto records what you enter and counts it. It is not a medical device, it does not diagnose, and it does not replace a clinician.":
   "Tratto registra quello che scrivi e ne mostra il conteggio. Non è un dispositivo medico, non formula diagnosi e non sostituisce il parere di un medico.",
 "Tratto records what you enter and shows counts and summaries of it. It does not link foods to symptoms, and it will not: on the numbers a personal diary produces, such a link could not be told apart from chance. It is not a medical device, it does not diagnose, and it does not replace a clinician. Talk to a doctor or a dietitian before changing what you eat.":
   "Tratto registra quello che inserisci e ne mostra ricorrenze e riepiloghi. Non mette in relazione gli alimenti con i sintomi e non lo farà: sui numeri che un diario personale produce, una relazione del genere non sarebbe distinguibile dal caso. Non è un dispositivo medico, non formula diagnosi e non sostituisce il parere di un medico. Parla con un medico o con un dietista prima di cambiare la tua alimentazione.",
 "Two days %lld days apart no longer resemble each other appreciably. That is the number a washout between two conditions would have to respect.":
   "Due giorni distanti %lld giorni non si somigliano più in modo apprezzabile. È il numero che una pausa fra due condizioni dovrebbe rispettare.",
 "Typical difference": "Differenza tipica",
 "Typical swing (SD)": "Oscillazione tipica (DS)",
 "Unusual day": "Giornata fuori dal solito",
 "Urgency": "Urgenza",
 "Usual breakfast": "Solita colazione",
 "Usual meals": "Pasti ricorrenti",
 "Usual snack": "Solito spuntino",
 "Version": "Versione",
 "What Tratto is for": "A che cosa serve Tratto",
 "What came up on re-reading the data": "Cosa è emerso rileggendo i dati",
 "What counts as the outcome": "Che cosa conta come esito",
 "What did you eat?": "Che cosa hai mangiato?",
 "What it does": "Che cosa fa",
 "What it does not do, and why": "Che cosa non fa, e perché",
 "What it produces": "Che cosa produce",
 "What to compare": "Che cosa confrontare",
 "What you can hope to see": "Che cosa puoi sperare di vedere",
 "When a trigger is already known — coeliac disease, a diagnosed intolerance — and what matters is adherence and how things are going.":
   "Quando il colpevole è già noto, per esempio una celiachia o un'intolleranza diagnosticata, e quello che conta è l'aderenza e come sta andando.",
 "When coverage falls below 70% over a week, the app marks the period as not analysable rather than showing numbers that look sound.":
   "Quando la copertura scende sotto il 70% su una settimana, l'app dichiara il periodo non analizzabile invece di mostrare numeri che sembrano validi.",
 "When someone else will read it: a diary written as you go is worth more than one reconstructed the evening before.":
   "Quando lo leggerà qualcun altro: un diario scritto man mano vale più di uno ricostruito la sera prima.",
 "When the between-days share is low, a daily average is mostly noise.":
   "Quando la quota fra giorni è bassa, la media di una giornata è per lo più rumore.",
 "Where we put our hands up": "Dove alziamo le mani",
 "Whether a food affects you is, in most cases, not knowable from a diary alone. Tratto says so instead of guessing.":
   "Se un alimento ti riguardi o no, nella maggior parte dei casi, da un diario soltanto non si può sapere. Tratto lo dice invece di tirare a indovinare.",
 "Which meals actually got recorded": "Quali pasti venivano registrati davvero",
 "Who needs this diary anyway": "A chi serve comunque questo diario",
 "Whole foods cannot be blinded: you will know which block is which. The comparison ingredient is not a placebo, it is something you do not suspect, so that expectation has something to be measured against.":
   "Gli alimenti interi non si possono accecare: saprai quale blocco è quale. L'ingrediente di confronto non è un placebo, è qualcosa che non sospetti, così che l'aspettativa abbia qualcosa contro cui essere misurata.",
 "Why a planned comparison": "Perché un confronto programmato",
 "Why those results did not hold": "Perché quei risultati non reggevano",
 "With %lld pairs no result can be significant, whatever happens. You would need at least 6 pairs for a two-sided hypothesis, or 5 for a one-sided one.":
   "Con %lld coppie nessun risultato può essere significativo, qualunque cosa succeda. Ne servirebbero almeno 6 per un'ipotesi bilaterale, o 5 per una unilaterale.",
 "Worst abdominal pain in the last 24 hours": "Il peggior dolore alla pancia nelle ultime 24 ore",
 "Write them the way you would say them out loud. One tap on the Now screen logs them.":
   "Scrivili come li diresti ad alta voce. Un tocco nella schermata Adesso li registra.",
 "You pick one ingredient to test and one to compare it against.":
   "Scegli un ingrediente da provare e uno con cui confrontarlo.",
 "Your own series still resembles itself 3 days later and stops doing so at 4. That is where the default gap comes from, not from a protocol.":
   "La tua serie si somiglia ancora a 3 giorni di distanza e smette di farlo a 4. Da lì viene la pausa predefinita, non da un protocollo.",
 "Your pain moves by about %@ points from one day to the next with nothing in particular happening. That is worth knowing before you can say whether anything changes it.":
   "Il tuo dolore cambia di circa %@ punti da un giorno all'altro senza che sia successo niente di particolare. Serve saperlo prima di poter dire se qualcosa lo cambia davvero.",
 "and %lld more.": "e altri %lld.",
 "blood": "sangue",
 "complete days": "giorni completi",
 "condiments": "condimenti",
 "courses": "portate",
 "days of %lld": "giorni su %lld",
 "event": "evento",
 "events": "eventi",
 "foods": "alimenti",
 "last 7 days": "ultimi 7 giorni",
 "meals": "pasti",
 "meals answered": "fasce risolte",
 "no data": "nessun dato",
 "not set": "non indicato",
 "pain": "dolore",
 "pain %lld": "dolore %lld",
 "urgency %lld": "urgenza %lld",
 "· %lld days": "· %lld giorni",
 "…in 7 pairs out of 10": "…in 7 coppie su 10",
 "…in 8 pairs out of 10": "…in 8 coppie su 10",
 "…in 9 pairs out of 10": "…in 9 coppie su 10",
 "≥ %@ points": "≥ %@ punti",
 "Block done": "Blocco concluso",
}


# Chiavi che Xcode NON estrae, perche' non compaiono come stringhe letterali in
# posizione localizzabile: sono valori di enum, risolti a runtime con
# `LocalizedStringKey(variabile)` o `testo(_:_:)`. Vanno dichiarate a mano,
# altrimenti l'app mostra la chiave grezza e nessun build fallisce.
MANUALI = {
 # forma delle feci: etichette
 "Hard pellets": "Palline dure",
 "Lumpy": "Grumosa",
 "Cracked": "Con crepe",
 "Smooth": "Liscia",
 "Soft pieces": "Pezzi morbidi",
 "Mushy": "Poltiglia",
 "Liquid": "Liquida",
 # forma delle feci: descrizioni
 "Separate hard pellets, hard to pass": "Palline separate e dure, difficili da espellere",
 "One compact piece with a lumpy surface": "Un unico pezzo compatto, con la superficie a grumi",
 "One long piece with cracks on the surface": "Un unico pezzo allungato, con delle crepe sopra",
 "One long piece, smooth and soft": "Un unico pezzo allungato, liscio e morbido",
 "Soft pieces with clear-cut edges": "Pezzi morbidi con i bordi ben definiti",
 "Ragged pieces, mushy texture": "Pezzi sfrangiati, consistenza di poltiglia",
 "Liquid, with no solid pieces": "Liquida, senza pezzi solidi",
 # fasce
 "Breakfast": "Colazione",
 "Morning snack": "Spuntino del mattino",
 "Lunch": "Pranzo",
 "Afternoon snack": "Merenda",
 "Dinner": "Cena",
 "Evening snack": "Spuntino della sera",
 # stato del pasto
 "Logged": "Registrato",
 # quantita'
 "A little": "Poca",
 "Normal": "Normale",
 "A lot": "Tanta",
 # concetti dell'export
 "Stool form (local 1-7 scale)": "Forma delle feci (scala locale 1-7)",
 "Bowel movements per day": "Evacuazioni al giorno",
 "Worst abdominal pain in the last 24 hours (0-10)":
   "Peggior dolore addominale nelle ultime 24 ore (0-10)",
 "Perceived urgency (0-10)": "Urgenza percepita (0-10)",
 "Perceived bloating (0-10)": "Gonfiore percepito (0-10)",
 "Day with at least one bowel movement outside the middle range":
   "Giornata con almeno un'evacuazione fuori dall'intervallo centrale",
 "A 7-level ordinal scale with its own labels and illustrations, ordered from the most compact form (1) to liquid (7). It is not the Bristol scale and the values must not be read as such.":
   "Scala ordinale a 7 livelli con etichette e illustrazioni proprie, ordinata dalla forma piu' compatta (1) alla liquida (7). Non e' la scala di Bristol e i valori non vanno letti come tali.",
 "Self-reported 0-10 numeric scale, recorded once a day.":
   "Scala numerica 0-10 auto-riferita, una rilevazione al giorno.",
 # qualita' dei dati dell'archivio 2020
 "foods with no category": "alimenti senza categoria",
 "missing values in events": "valori mancanti negli eventi",
 "empty event rows, discarded": "righe di evento vuote, scartate",
 "duplicate entries in the lists": "voci duplicate in anagrafica",
 "references to entries that do not exist": "riferimenti a voci inesistenti",
 "dates that could not be read": "date non interpretabili",
 "non-numeric values": "valori non numerici",
 # fase 2
 "Mean daily pain (0-10)": "Dolore medio giornaliero (0-10)",
 "Share of days outside the middle range": "Quota di giornate fuori dall'intervallo centrale",
 "Any difference (two-sided)": "Una differenza qualsiasi (bilaterale)",
 "The target makes it worse (one-sided)": "Il bersaglio peggiora le cose (unilaterale)",
 "Comparison": "Confronto",
 "Consistent with an effect": "Coerente con un effetto",
 "No detectable effect": "Nessun effetto rilevabile",
 "Inconclusive": "Non concludente",
 "Protocol changed after it was frozen": "Piano cambiato dopo il congelamento",
 "Not finished yet": "Non ancora finito",
}

SEGNAPOSTO = re.compile(r'%(?:\d+\$)?(?:lld|ld|@|lf|f|d)')


def main():
    percorso = Path(sys.argv[1] if len(sys.argv) > 1 else "Tratto/Resources/Localizable.xcstrings")
    cat = json.loads(percorso.read_text())

    # `xcstringstool sync` non toglie le chiavi sparite dal codice: le marca
    # obsolete, o lascia un guscio vuoto. Vanno via, altrimenti il controllo di
    # completezza fallisce per sempre su voci che non esistono piu'.
    obsolete = [k for k, v in cat["strings"].items()
                if not k or v.get("extractionState") == "stale"]
    for k in obsolete:
        del cat["strings"][k]

    # le chiavi risolte a runtime vanno inserite a mano nel catalogo
    aggiunte = 0
    for chiave in MANUALI:
        if chiave not in cat["strings"]:
            cat["strings"][chiave] = {"extractionState": "manual"}
            aggiunte += 1

    IT.update(MANUALI)
    mancanti, difformi, tradotte = [], [], 0
    for chiave, voce in cat["strings"].items():
        it = IT.get(chiave)
        if it is None:
            mancanti.append(chiave)
            continue
        # i segnaposto devono restare identici e nello stesso ordine
        a, b = SEGNAPOSTO.findall(chiave), SEGNAPOSTO.findall(it)
        if a != b:
            difformi.append((chiave, a, b))
            continue
        voce.setdefault("localizations", {})["it"] = {
            "stringUnit": {"state": "translated", "value": it}
        }
        # la lingua sorgente va scritta esplicitamente, altrimenti una chiave
        # che non finisce in en.lproj mostra la chiave grezza a schermo
        voce["localizations"]["en"] = {
            "stringUnit": {"state": "translated", "value": chiave}
        }
        tradotte += 1

    percorso.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n")

    print(f"chiavi nel catalogo : {len(cat['strings'])}")
    print(f"obsolete rimosse    : {len(obsolete)}")
    print(f"manuali aggiunte    : {aggiunte}")
    print(f"tradotte            : {tradotte}")
    print(f"senza traduzione    : {len(mancanti)}")
    for m in mancanti:
        print("   +", repr(m))
    print(f"segnaposto difformi : {len(difformi)}")
    for c, a, b in difformi:
        print("   !", repr(c)[:70], a, "->", b)
    # le traduzioni scritte qui e non piu' presenti nel codice
    orfane = sorted(set(IT) - set(cat["strings"]))
    print(f"traduzioni orfane   : {len(orfane)}")
    for o in orfane[:10]:
        print("   -", repr(o)[:80])
    sys.exit(1 if (mancanti or difformi) else 0)


if __name__ == "__main__":
    main()
