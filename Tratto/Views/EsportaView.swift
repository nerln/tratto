import SwiftUI
import SwiftData

struct EsportaView: View {
    @Environment(\.modelContext) private var contesto

    @Query private var eventi: [EventoIntestinale]
    @Query private var pasti: [Pasto]
    @Query private var esiti: [EsitoGiornaliero]
    @Query private var contesti: [ContestoGiornaliero]
    @Query private var impostazioni: [Impostazioni]

    @State private var generati: [URL] = []
    @State private var errore: String?
    @State private var inCorso = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Sezione("Che cosa produce") {
                    Voce("Referto PDF", "Una pagina sola: periodo coperto, quante evacuazioni, "
                         + "come si distribuiscono le forme, l'andamento del dolore, e la nota "
                         + "che dice quale scala è stata usata. Nessuna conclusione: è il documento "
                         + "da portare a una visita.")
                    Voce("Tre CSV", "Eventi, pasti espansi una riga per ingrediente, e un file "
                         + "giornaliero con esiti, contesto e copertura. È la strada verso R.")
                    Voce("JSON", "Tutto, per il backup e per passare i dati fra Mac e telefono "
                         + "come file: non c'è nessuna sincronizzazione automatica.")
                    Voce("FHIR", "Un bundle con una osservazione per evento. Ogni codice porta "
                         + "sempre la codifica locale.")
                }

                if let i = impostazioni.first {
                    Sezione("Codifiche esterne") {
                        Toggle("Aggiungi SNOMED CT e LOINC all'export",
                               isOn: Binding(get: { i.codificheEsterneNellExport },
                                             set: { i.codificheEsterneNellExport = $0; try? contesto.save() }))
                        Text("Spento di default. La forma delle feci ha un concetto SNOMED CT ma "
                             + "nessun codice LOINC (l'unico «Bristol» presente in LOINC è una marca "
                             + "di sigarette); il dolore da 0 a 10 ha invece un codice LOINC pubblico. "
                             + "SNOMED CT però non è libero in Italia, che non è fra i paesi membri: "
                             + "per questo la codifica locale c'è sempre e quelle esterne si aggiungono "
                             + "solo se le vuoi.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await genera() }
                } label: {
                    Label(inCorso ? "Genero…" : "Genera i file", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(inCorso)

                if !generati.isEmpty {
                    Sezione("File pronti") {
                        ForEach(generati, id: \.self) { url in
                            HStack {
                                Image(systemName: simbolo(url))
                                Text(url.lastPathComponent).font(.callout)
                                Spacer()
                                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            }
                        }
                        Text("Sono nella cartella temporanea dell'app: condividili o salvali dove vuoi.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let e = errore { Nota(colore: .red, testo: e) }

                Text(Testi.disclaimerEsteso).font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Esporta")
    }

    private func Voce(_ titolo: String, _ testo: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titolo).font(.callout.weight(.semibold))
            Text(testo).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func simbolo(_ url: URL) -> String {
        switch url.pathExtension {
        case "pdf": "doc.richtext"
        case "csv": "tablecells"
        default: "curlybraces"
        }
    }

    private func istantanea() -> Esportazione.Istantanea {
        let riepilogo = Riepilogo.costruisci(da: .init(
            eventi: eventi.map { ($0.quando, $0.forma, $0.dolore) },
            pasti: pasti.map { ($0.quando, $0.fascia, $0.risolto) },
            vociPasto: pasti.flatMap { p in
                p.vociOrdinate.compactMap { v in
                    guard let i = v.ingrediente else { return nil }
                    return (p.quando, i.identificativo, i.nome, i.categoria)
                }
            },
            esiti: esiti.map { ($0.giorno, $0.dolorePeggiore) }))

        var vociPasto: [Esportazione.Istantanea.VocePasto] = []
        for p in pasti {
            if p.stato != .registrato || (p.voci ?? []).isEmpty {
                vociPasto.append(.init(quando: p.quando, fascia: p.fascia.nome,
                                       stato: p.stato.rawValue, ingredienteId: "",
                                       ingredienteNome: "", categoria: "", quantita: "",
                                       testoGrezzo: p.testoGrezzo))
            } else {
                for v in p.vociOrdinate {
                    guard let i = v.ingrediente else { continue }
                    vociPasto.append(.init(quando: p.quando, fascia: p.fascia.nome,
                                           stato: p.stato.rawValue, ingredienteId: i.identificativo,
                                           ingredienteNome: i.nome, categoria: i.categoria,
                                           quantita: v.quantita.rawValue, testoGrezzo: p.testoGrezzo))
                }
            }
        }

        let perGiorno = Dictionary(contesti.map { (Calendar.current.startOfDay(for: $0.giorno), $0) },
                                   uniquingKeysWith: { a, _ in a })
        var giorni: [Esportazione.Istantanea.Giorno] = []
        var visti = Set<Date>()
        for e in esiti {
            let g = Calendar.current.startOfDay(for: e.giorno)
            visti.insert(g)
            let c = perGiorno[g]
            giorni.append(.init(giorno: g, dolore: e.dolorePeggiore, gonfiore: e.gonfiore,
                                oreSonno: c?.oreSonno, stress: c?.stress, caffe: c?.caffe,
                                alcol: c?.alcol, esercizio: c?.esercizio,
                                atipica: c?.giornataAtipica ?? false))
        }
        for (g, c) in perGiorno where !visti.contains(g) {
            giorni.append(.init(giorno: g, dolore: nil, gonfiore: nil, oreSonno: c.oreSonno,
                                stress: c.stress, caffe: c.caffe, alcol: c.alcol,
                                esercizio: c.esercizio, atipica: c.giornataAtipica))
        }

        return .init(
            eventi: eventi.map { .init(quando: $0.quando, forma: $0.forma, urgenza: $0.urgenza,
                                       dolore: $0.dolore, sangue: $0.sangue, note: $0.note) },
            pasti: vociPasto, giorni: giorni, riepilogo: riepilogo,
            codificheEsterne: impostazioni.first?.codificheEsterneNellExport ?? false)
    }

    @MainActor
    private func genera() async {
        inCorso = true
        errore = nil
        defer { inCorso = false }
        let dati = istantanea()
        let cartella = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tratto-export", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: cartella)
            try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)

            var prodotti: [URL] = []
            func scrivi(_ nome: String, _ contenuto: Data) throws {
                let url = cartella.appendingPathComponent(nome)
                try contenuto.write(to: url)
                prodotti.append(url)
            }
            if let pdf = Referto.pdf(dati) { try scrivi("tratto-referto.pdf", pdf) }
            try scrivi("tratto-eventi.csv", Data(Esportazione.csvEventi(dati).utf8))
            try scrivi("tratto-pasti.csv", Data(Esportazione.csvPasti(dati).utf8))
            try scrivi("tratto-giorni.csv", Data(Esportazione.csvGiorni(dati).utf8))
            try scrivi("tratto-dati.json", Esportazione.json(dati))
            try scrivi("tratto-fhir.json", Esportazione.fhir(dati))
            generati = prodotti
        } catch {
            errore = "Non sono riuscito a scrivere i file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Referto

/// Il documento che ha senso portare a una visita: una pagina, dati grezzi,
/// nessuna conclusione, e in fondo la nota che spiega quale scala si sta
/// leggendo, perché non è una scala nota.
enum Referto {

    @MainActor
    static func pdf(_ dati: Esportazione.Istantanea) -> Data? {
        let renderizzatore = ImageRenderer(content: RefertoView(dati: dati))
        renderizzatore.proposedSize = ProposedViewSize(width: 595, height: 842) // A4 a 72 dpi
        var risultato: Data?
        let mutabile = NSMutableData()
        renderizzatore.render { dimensione, disegna in
            var riquadro = CGRect(x: 0, y: 0, width: 595, height: max(842, dimensione.height))
            guard let consumatore = CGDataConsumer(data: mutabile),
                  let contesto = CGContext(consumer: consumatore, mediaBox: &riquadro, nil)
            else { return }
            contesto.beginPDFPage(nil)
            disegna(contesto)
            contesto.endPDFPage()
            contesto.closePDF()
            risultato = mutabile as Data
        }
        return risultato
    }
}

struct RefertoView: View {
    let dati: Esportazione.Istantanea

    private var r: Riepilogo { dati.riepilogo }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Diario intestinale e alimentare").font(.title2.weight(.semibold))
                if let p = r.periodo {
                    Text("Periodo osservato: dal \(p.inizio.formatted(date: .numeric, time: .omitted)) "
                         + "al \(p.fine.formatted(date: .numeric, time: .omitted))")
                        .font(.footnote)
                }
                Text("Prodotto da Tratto, diario compilato dal paziente. Dati non verificati da terzi.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            griglia([
                ("Giorni con registrazioni", "\(r.giornate.filter { $0.eventi > 0 || $0.fasceRisolte > 0 }.count)"),
                ("Giorni completi", "\(r.giorniCompletiTotali)"),
                ("Evacuazioni totali", "\(r.eventiTotali)"),
                ("Evacuazioni al giorno (media)", r.evacuazioniPerGiorno.media.map { Formati.decimale($0) } ?? "—"),
            ])

            blocco("Distribuzione della forma delle feci") {
                ForEach(FormaFecale.allCases) { f in
                    let n = r.distribuzioneForme[f.rawValue] ?? 0
                    let tot = max(1, r.eventiTotali)
                    HStack(spacing: 8) {
                        Text("\(f.rawValue)").font(.caption.monospacedDigit()).frame(width: 12)
                        Text(f.etichetta).font(.caption).frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.75))
                                .frame(width: geo.size.width * CGFloat(n) / CGFloat(tot))
                        }
                        .frame(height: 9)
                        Text("\(n)").font(.caption.monospacedDigit()).frame(width: 26, alignment: .trailing)
                    }
                }
                let (a, o) = r.giorniAnormaliSuOsservati
                if o > 0 {
                    Text("Giornate con almeno un'evacuazione fuori dall'intervallo centrale (1-2 o 6-7): \(a) su \(o).")
                        .font(.caption).padding(.top, 2)
                }
            }

            blocco("Dolore addominale, peggiore nelle ultime 24 ore (0-10)") {
                griglia([
                    ("Giorni con la voce compilata", "\(r.dolore.osservazioni)"),
                    ("Mediana", r.dolore.mediana.map { Formati.decimale($0) } ?? "—"),
                    ("Minimo e massimo",
                     (r.dolore.minimo.map { Formati.decimale($0, cifre: 0) } ?? "—") + " – "
                     + (r.dolore.massimo.map { Formati.decimale($0, cifre: 0) } ?? "—")),
                    ("Oscillazione tipica (DS)", r.dolore.deviazioneStandard.map { Formati.decimale($0) } ?? "—"),
                ])
            }

            blocco("Completezza del diario alimentare") {
                Text("Copertura media delle fasce attese (colazione, pranzo, cena) negli ultimi 7 giorni: "
                     + "\(Int((r.finestra7.frazioneMedia * 100).rounded()))%.")
                    .font(.caption)
                if !r.finestra7.analizzabile {
                    Text("Sotto il 70% l'alimentazione della maggior parte delle giornate non è nota.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Nota sulle scale").font(.caption.weight(.semibold))
                if let n = Concetto.formaFecale.notaPerIlClinico {
                    Text(n).font(.caption2).foregroundStyle(.secondary)
                }
                Text("Il dolore è raccolto su scala numerica 0-10 auto-riferita, una volta al giorno.")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("Questo documento riporta soltanto quello che è stato registrato. Non contiene "
                     + "correlazioni fra alimenti e sintomi, non formula ipotesi diagnostiche e non "
                     + "è prodotto da un dispositivo medico.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(34)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func griglia(_ voci: [(String, String)]) -> some View {
        VStack(spacing: 3) {
            ForEach(voci, id: \.0) { k, v in
                HStack {
                    Text(k).font(.caption)
                    Spacer()
                    Text(v).font(.caption.monospacedDigit().weight(.medium))
                }
            }
        }
    }

    private func blocco<C: View>(_ titolo: String, @ViewBuilder contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo).font(.footnote.weight(.semibold))
            contenuto()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }
}
