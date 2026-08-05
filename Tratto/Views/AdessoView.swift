import SwiftUI
import SwiftData

/// La schermata che decide se ci saranno dati o no.
///
/// Nel 2020 la colazione risultava annotata 25 volte su 59 giorni e lo spuntino
/// del mattino una volta sola: non per pigrizia, ma perché un evento in bagno
/// si ricorda e una colazione uguale a tutte le altre no. Da qui le tre scelte
/// di questa schermata: due soli bersagli grandi, i pasti ricorrenti a un
/// tocco, e soprattutto la possibilità di dire "niente", che trasforma una
/// fascia saltata da buco in dato.
struct AdessoView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.locale) private var locale

    @Query(sort: \EventoIntestinale.quando, order: .reverse) private var eventi: [EventoIntestinale]
    @Query(sort: \Pasto.quando, order: .reverse) private var pasti: [Pasto]
    @Query private var impostazioni: [Impostazioni]
    @Query private var esiti: [EsitoGiornaliero]

    @State private var mostraEvento = false
    @State private var mostraPasto = false
    @State private var testoIniziale = ""
    @State private var mostraEsitoSera = false
    @State private var mostraPreferenze = false

    private var oggi: Date { Calendar.current.startOfDay(for: .now) }

    private var eventiDiOggi: [EventoIntestinale] {
        eventi.filter { Calendar.current.isDate($0.quando, inSameDayAs: .now) }
    }
    private var pastiDiOggi: [Pasto] {
        pasti.filter { Calendar.current.isDate($0.quando, inSameDayAs: .now) }
    }
    private var fasceRisolteOggi: Set<Fascia> {
        Set(pastiDiOggi.filter(\.risolto).map(\.fascia))
    }
    private var fasceMancanti: [Fascia] {
        Fascia.attese.filter { !fasceRisolteOggi.contains($0) }
    }
    private var doloreDiOggi: Int? {
        esiti.first { Calendar.current.isDate($0.giorno, inSameDayAs: .now) }?.dolorePeggiore
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                bersagli
                statoDiOggi
                if !fasceMancanti.isEmpty { mancanti }
                scorciatoie
                riepilogoDiOggi
                nota
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Now")
        .toolbar {
            ToolbarItem {
                Button { mostraPreferenze = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $mostraEvento) { RegistraEventoView() }
        .sheet(isPresented: $mostraPasto) { RegistraPastoView(testoIniziale: testoIniziale) }
        .sheet(isPresented: $mostraEsitoSera) { EsitoSeraView(giorno: oggi) }
        .sheet(isPresented: $mostraPreferenze) { PreferenzeView() }
    }

    // MARK: - I due bersagli

    private var bersagli: some View {
        VStack(spacing: 12) {
            BottoneGrande(titolo: "Bathroom", simbolo: "toilet.fill",
                          colore: .accentColor) { mostraEvento = true }
            BottoneGrande(titolo: "Meal", simbolo: "fork.knife",
                          colore: .orange) { testoIniziale = ""; mostraPasto = true }
        }
    }

    // MARK: - Stato

    private var statoDiOggi: some View {
        HStack(spacing: 10) {
            Pillola(valore: "\(eventiDiOggi.count)",
                    etichetta: eventiDiOggi.count == 1 ? "event" : "events")
            Pillola(valore: "\(fasceRisolteOggi.intersection(Fascia.attese).count)/\(Fascia.attese.count)",
                    etichetta: "meals answered")
            Pillola(valore: doloreDiOggi.map { "\($0)" } ?? "—", etichetta: "pain")
        }
    }

    // MARK: - Le fasce ancora aperte

    private var mancanti: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Still open today")
                .font(.subheadline.weight(.semibold))
            ForEach(fasceMancanti) { fascia in
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(fascia.chiaveNome))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Nothing") { segna(fascia, stato: .digiuno) }
                        .buttonStyle(.bordered)
                    Button("Can't recall") { segna(fascia, stato: .nonRicordato) }
                        .buttonStyle(.bordered)
                }
                .font(.callout)
            }
            Text("Knowing that you ate nothing is data. A slot left blank is not.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.09)))
    }

    // MARK: - Ricorrenti

    private var scorciatoie: some View {
        VStack(alignment: .leading, spacing: 8) {
            let s = impostazioni.first
            if let t = s?.solitaColazione, !t.isEmpty {
                Button {
                    testoIniziale = t; mostraPasto = true
                } label: {
                    Label("Usual breakfast", systemImage: "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            if let t = s?.solitoSpuntino, !t.isEmpty {
                Button {
                    testoIniziale = t; mostraPasto = true
                } label: {
                    Label("Usual snack", systemImage: "takeoutbag.and.cup.and.straw.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            Button {
                mostraEsitoSera = true
            } label: {
                Label(doloreDiOggi == nil ? "Record today's pain" : "Edit today's pain",
                      systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Cronologia breve

    @ViewBuilder
    private var riepilogoDiOggi: some View {
        let voci = vociDiOggi
        if !voci.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today").font(.subheadline.weight(.semibold))
                ForEach(voci, id: \.chiave) { voce in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(voce.ora)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        if let forma = voce.forma {
                            DisegnoForma(forma: forma, altezza: 18).frame(width: 44)
                        }
                        Text(voce.testo)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.09)))
        }
    }

    private struct VoceOggi { var chiave: String; var ora: String; var testo: String; var forma: FormaFecale? }

    private var vociDiOggi: [VoceOggi] {
        let formattatore = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        var v: [(Date, VoceOggi)] = []
        for e in eventiDiOggi {
            let forma = FormaFecale(rawValue: e.forma)
            v.append((e.quando, VoceOggi(chiave: "e\(e.identificativo)",
                                         ora: e.quando.formatted(formattatore),
                                         testo: forma?.etichetta(locale) ?? "",
                                         forma: forma)))
        }
        for p in pastiDiOggi {
            let descrizione: String
            switch p.stato {
            case .digiuno, .nonRicordato:
                descrizione = "\(p.fascia.nome(locale)): \(p.stato.nome(locale).lowercased())"
            case .registrato:
                let nomi = p.vociOrdinate.compactMap { $0.ingrediente?.nome(locale) }
                descrizione = nomi.isEmpty ? p.testoGrezzo : nomi.joined(separator: ", ")
            }
            v.append((p.quando, VoceOggi(chiave: "p\(p.identificativo)",
                                         ora: p.quando.formatted(formattatore),
                                         testo: descrizione, forma: nil)))
        }
        return v.sorted { $0.0 > $1.0 }.map(\.1)
    }

    private var nota: some View {
        Text(Testi.disclaimerBreve)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private func segna(_ fascia: Fascia, stato: StatoPasto) {
        var componenti = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        componenti.hour = fascia.oraTipica
        let quando = Calendar.current.date(from: componenti) ?? .now
        contesto.insert(Pasto(quando: quando, fascia: fascia, stato: stato, fonte: .manuale))
        try? contesto.save()
    }
}

// MARK: - Componenti

struct BottoneGrande: View {
    let titolo: LocalizedStringKey
    let simbolo: String
    let colore: Color
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 14) {
                Image(systemName: simbolo).font(.system(size: 30, weight: .semibold))
                Text(titolo).font(.title2.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(RoundedRectangle(cornerRadius: 18).fill(colore.gradient))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Pillola: View {
    let valore: String
    let etichetta: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(valore).font(.title3.weight(.semibold).monospacedDigit())
            Text(etichetta).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.09)))
    }
}

enum Testi {
    static let disclaimerBreve: LocalizedStringKey =
        "Tratto records what you enter and counts it. It is not a medical device, it does not diagnose, and it does not replace a clinician."

    static let disclaimerEsteso: LocalizedStringKey =
        "Tratto records what you enter and shows counts and summaries of it. It does not link foods to symptoms, and it will not: on the numbers a personal diary produces, such a link could not be told apart from chance. It is not a medical device, it does not diagnose, and it does not replace a clinician. Talk to a doctor or a dietitian before changing what you eat."
}
