import SwiftUI
import SwiftData

struct EsportaView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.locale) private var locale

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
                Sezione("What it produces") {
                    Voce("PDF report", "One page: period covered, how many bowel movements, how the forms are distributed, how pain went, and the note that says which scale was used. No conclusions: this is the document to bring to an appointment.")
                    Voce("Three CSV files", "Events, meals expanded one row per ingredient, and a daily file with outcomes, context and coverage. This is the road to R.")
                    Voce("JSON", "Everything, for backup and for moving data between Mac and phone as a file: there is no automatic sync.")
                    Voce("FHIR", "A bundle with one observation per event. Every code always carries the local coding.")
                }

                if let i = impostazioni.first {
                    Sezione("External codings") {
                        Toggle("Add SNOMED CT and LOINC to the export",
                               isOn: Binding(get: { i.codificheEsterneNellExport },
                                             set: { i.codificheEsterneNellExport = $0; try? contesto.save() }))
                        Text("Off by default. Stool form has a SNOMED CT concept but no LOINC code at all (the only «Bristol» in LOINC is a cigarette brand); pain from 0 to 10 does have a public LOINC code. SNOMED CT, however, is not free in Italy, which is not a member country: this is why the local coding is always there and the external ones are added only if you want them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await genera() }
                } label: {
                    Label(inCorso ? "Generating…" : "Generate the files", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(inCorso)

                if !generati.isEmpty {
                    Sezione("Files ready") {
                        ForEach(generati, id: \.self) { url in
                            HStack {
                                Image(systemName: simbolo(url))
                                Text(url.lastPathComponent).font(.callout)
                                Spacer()
                                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            }
                        }
                        Text("They are in the app's temporary folder: share them or save them wherever you like.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let e = errore { Nota(colore: .red, testo: Text(verbatim: e)) }

                Text(Testi.disclaimerEsteso).font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Export")
    }

    private func Voce(_ titolo: LocalizedStringKey, _ testo: LocalizedStringKey) -> some View {
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
                    return (p.quando, i.identificativo, i.nome(locale), i.categoria(locale))
                }
            },
            esiti: esiti.map { ($0.giorno, $0.dolorePeggiore) }))

        var vociPasto: [Esportazione.Istantanea.VocePasto] = []
        for p in pasti {
            if p.stato != .registrato || (p.voci ?? []).isEmpty {
                vociPasto.append(.init(quando: p.quando, fascia: p.fascia.chiaveNome,
                                       stato: p.stato.rawValue, ingredienteId: "",
                                       ingredienteNome: "", categoria: "", quantita: "",
                                       testoGrezzo: p.testoGrezzo))
            } else {
                for v in p.vociOrdinate {
                    guard let i = v.ingrediente else { continue }
                    vociPasto.append(.init(quando: p.quando, fascia: p.fascia.chiaveNome,
                                           stato: p.stato.rawValue, ingredienteId: i.identificativo,
                                           ingredienteNome: i.nomeEn, categoria: i.categoriaEn,
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
            codificheEsterne: impostazioni.first?.codificheEsterneNellExport ?? false,
            locale: locale)
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
            errore = String(localized: "Could not write the files: \(error.localizedDescription)", locale: locale)
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
        let renderizzatore = ImageRenderer(content:
            RefertoView(dati: dati).environment(\.locale, dati.locale))
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
    private var locale: Locale { dati.locale }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bowel and food diary").font(.title2.weight(.semibold))
                if let p = r.periodo {
                    Text("Period observed: \(p.inizio.formatted(date: .numeric, time: .omitted)) to \(p.fine.formatted(date: .numeric, time: .omitted))")
                        .font(.footnote)
                }
                Text("Produced by Tratto, a diary kept by the patient. Data not verified by a third party.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            griglia([
                (Text("Days with entries"), "\(r.giornate.filter { $0.eventi > 0 || $0.fasceRisolte > 0 }.count)"),
                (Text("Complete days"), "\(r.giorniCompletiTotali)"),
                (Text("Total bowel movements"), "\(r.eventiTotali)"),
                (Text("Bowel movements per day (mean)"),
                 r.evacuazioniPerGiorno.media.map { Formati.decimale($0) } ?? "—"),
            ])

            blocco("Distribution of stool form") {
                ForEach(FormaFecale.allCases) { f in
                    let n = r.distribuzioneForme[f.rawValue] ?? 0
                    let tot = max(1, r.eventiTotali)
                    HStack(spacing: 8) {
                        Text(verbatim: "\(f.rawValue)").font(.caption.monospacedDigit()).frame(width: 12)
                        Text(verbatim: f.etichetta(locale)).font(.caption)
                            .frame(width: 116, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.75))
                                .frame(width: geo.size.width * CGFloat(n) / CGFloat(tot))
                        }
                        .frame(height: 9)
                        Text(verbatim: "\(n)").font(.caption.monospacedDigit())
                            .frame(width: 26, alignment: .trailing)
                    }
                }
                let (a, o) = r.giorniAnormaliSuOsservati
                if o > 0 {
                    Text("Days with at least one bowel movement outside the middle range (1-2 or 6-7): \(a) of \(o).")
                        .font(.caption).padding(.top, 2)
                }
            }

            blocco("Abdominal pain, worst in the last 24 hours (0-10)") {
                griglia([
                    (Text("Days with the entry filled in"), "\(r.dolore.osservazioni)"),
                    (Text("Median"), r.dolore.mediana.map { Formati.decimale($0) } ?? "—"),
                    (Text("Minimum and maximum"),
                     (r.dolore.minimo.map { Formati.decimale($0, cifre: 0) } ?? "—") + " / "
                     + (r.dolore.massimo.map { Formati.decimale($0, cifre: 0) } ?? "—")),
                    (Text("Typical swing (SD)"),
                     r.dolore.deviazioneStandard.map { Formati.decimale($0) } ?? "—"),
                ])
            }

            blocco("Completeness of the food diary") {
                Text("Mean coverage of the expected slots (breakfast, lunch, dinner) over the last 7 days: \(Formati.percentuale(r.finestra7.frazioneMedia)).")
                    .font(.caption)
                if !r.finestra7.analizzabile {
                    Text("Below 70%, what was eaten on most days is not known.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Note on the scales").font(.caption.weight(.semibold))
                if let n = Concetto.formaFecale.notaPerIlClinico(locale) {
                    Text(verbatim: n).font(.caption2).foregroundStyle(.secondary)
                }
                Text("Pain is collected on a self-reported 0-10 numeric scale, once a day.")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("This document reports only what was recorded. It contains no correlations between foods and symptoms, makes no diagnostic hypotheses, and is not produced by a medical device.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(34)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func griglia(_ voci: [(Text, String)]) -> some View {
        VStack(spacing: 3) {
            ForEach(Array(voci.enumerated()), id: \.offset) { _, voce in
                HStack {
                    voce.0.font(.caption)
                    Spacer()
                    Text(verbatim: voce.1).font(.caption.monospacedDigit().weight(.medium))
                }
            }
        }
    }

    private func blocco<C: View>(_ titolo: LocalizedStringKey, @ViewBuilder contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo).font(.footnote.weight(.semibold))
            contenuto()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }
}
