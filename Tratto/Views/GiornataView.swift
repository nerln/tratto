import SwiftUI
import SwiftData

/// La cronologia, giorno per giorno. Serve a rileggere e correggere, non a
/// concludere: qui non compare nessun accostamento fra quello che ha mangiato
/// e quello che e' successo dopo.
struct GiornataView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.locale) private var locale

    @Query(sort: \EventoIntestinale.quando, order: .reverse) private var eventi: [EventoIntestinale]
    @Query(sort: \Pasto.quando, order: .reverse) private var pasti: [Pasto]
    @Query private var esiti: [EsitoGiornaliero]

    @State private var giorno: Date = Calendar.current.startOfDay(for: .now)
    @State private var eventoDaModificare: EventoIntestinale?
    @State private var pastoDaModificare: Pasto?
    @State private var mostraEsito = false

    private var eventiDelGiorno: [EventoIntestinale] {
        eventi.filter { Calendar.current.isDate($0.quando, inSameDayAs: giorno) }
            .sorted { $0.quando < $1.quando }
    }
    private var pastiDelGiorno: [Pasto] {
        pasti.filter { Calendar.current.isDate($0.quando, inSameDayAs: giorno) }
            .sorted { $0.quando < $1.quando }
    }
    private var esitoDelGiorno: EsitoGiornaliero? {
        esiti.first { Calendar.current.isDate($0.giorno, inSameDayAs: giorno) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navigatore
                intestazione
                if eventiDelGiorno.isEmpty && pastiDelGiorno.isEmpty {
                    vuoto
                } else {
                    linea
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Day")
        .sheet(item: $eventoDaModificare) { RegistraEventoView(evento: $0) }
        .sheet(item: $pastoDaModificare) { RegistraPastoView(pastoDaModificare: $0) }
        .sheet(isPresented: $mostraEsito) { EsitoSeraView(giorno: giorno) }
    }

    private var navigatore: some View {
        HStack {
            Button { sposta(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered)
            Spacer()
            DatePicker("Day", selection: $giorno, displayedComponents: .date)
                .labelsHidden()
            Spacer()
            Button { sposta(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
                .disabled(Calendar.current.isDateInToday(giorno))
        }
    }

    private var intestazione: some View {
        HStack(spacing: 10) {
            Pillola(valore: "\(eventiDelGiorno.count)", etichetta: "events")
            Pillola(valore: "\(Set(pastiDelGiorno.filter(\.risolto).map(\.fascia)).intersection(Fascia.attese).count)/\(Fascia.attese.count)",
                    etichetta: "meals answered")
            Button { mostraEsito = true } label: {
                Pillola(valore: esitoDelGiorno?.dolorePeggiore.map { "\($0)" } ?? "—",
                        etichetta: "pain")
            }
            .buttonStyle(.plain)
        }
    }

    private var vuoto: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
            Text("Nothing recorded on this day.")
                .foregroundStyle(.secondary)
            Text("A day with nothing in it stays a day with nothing in it: it does not count as observed.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var linea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(voci, id: \.chiave) { voce in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Text(voce.ora)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color.gray.opacity(0.25))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: 44)

                    Button { voce.apri() } label: {
                        HStack(alignment: .top, spacing: 10) {
                            if let forma = voce.forma {
                                DisegnoForma(forma: forma, altezza: 22).frame(width: 54)
                            } else {
                                Image(systemName: voce.simbolo)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 54)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voce.titolo).font(.callout.weight(.medium))
                                if let sotto = voce.sottotitolo, !sotto.isEmpty {
                                    Text(sotto).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.07)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private struct Voce {
        var chiave: String
        var quando: Date
        var ora: String
        var titolo: String
        var sottotitolo: String?
        var forma: FormaFecale?
        var simbolo: String
        var apri: () -> Void
    }

    private var voci: [Voce] {
        let f = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        var v: [Voce] = []
        for e in eventiDelGiorno {
            let forma = FormaFecale(rawValue: e.forma)
            var dettagli: [String] = []
            if let u = e.urgenza { dettagli.append(String(localized: "urgency \(u)", locale: locale)) }
            if let d = e.dolore { dettagli.append(String(localized: "pain \(d)", locale: locale)) }
            if e.sangue { dettagli.append(String(localized: "blood", locale: locale)) }
            if !e.note.isEmpty { dettagli.append(e.note) }
            v.append(Voce(chiave: "e\(e.identificativo)", quando: e.quando,
                          ora: e.quando.formatted(f),
                          titolo: forma?.etichetta(locale) ?? "",
                          sottotitolo: dettagli.joined(separator: " · "),
                          forma: forma, simbolo: "toilet",
                          apri: { eventoDaModificare = e }))
        }
        for p in pastiDelGiorno {
            let titolo: String
            var sotto: String?
            switch p.stato {
            case .digiuno, .nonRicordato:
                titolo = "\(p.fascia.nome(locale)): \(p.stato.nome(locale).lowercased())"
            case .registrato:
                titolo = p.fascia.nome(locale)
                let nomi = p.vociOrdinate.compactMap { $0.ingrediente?.nome(locale) }
                sotto = nomi.isEmpty ? p.testoGrezzo : nomi.joined(separator: ", ")
            }
            v.append(Voce(chiave: "p\(p.identificativo)", quando: p.quando,
                          ora: p.quando.formatted(f), titolo: titolo, sottotitolo: sotto,
                          forma: nil,
                          simbolo: p.stato == .registrato ? "fork.knife" : "minus.circle",
                          apri: { if p.stato == .registrato { pastoDaModificare = p } }))
        }
        return v.sorted { $0.quando < $1.quando }
    }

    private func sposta(_ giorni: Int) {
        if let nuovo = Calendar.current.date(byAdding: .day, value: giorni, to: giorno) {
            giorno = Calendar.current.startOfDay(for: nuovo)
        }
    }
}

