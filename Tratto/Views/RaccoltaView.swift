import SwiftUI
import SwiftData
import Charts

/// Che cosa si è raccolto finora, e quanto rumore c'è.
///
/// Non c'è nessuna classifica di alimenti e nessuna soglia magica del tipo
/// "servono quaranta esposizioni": quel numero, senza aver prima misurato
/// quanto oscilla l'esito da un giorno all'altro, sarebbe inventato. Il numero
/// vero compare qui sotto solo quando la serie è abbastanza lunga da produrlo.
struct RaccoltaView: View {
    @Environment(\.locale) private var locale

    @Query private var eventi: [EventoIntestinale]
    @Query private var pasti: [Pasto]
    @Query private var esiti: [EsitoGiornaliero]

    @State private var riepilogo: Riepilogo = .vuoto

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                copertura
                if riepilogo.eventiTotali > 0 { distribuzioneForme }
                if riepilogo.dolore.osservazioni > 0 { andamentoDolore }
                variabilita
                rilevabilita
                esposizioni
                Text(Testi.disclaimerEsteso)
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Collected")
        .onAppear(perform: ricalcola)
        .onChange(of: eventi.count) { ricalcola() }
        .onChange(of: pasti.count) { ricalcola() }
        .onChange(of: esiti.count) { ricalcola() }
    }

    // MARK: - Copertura

    private var copertura: some View {
        Sezione("Coverage") {
            HStack(spacing: 10) {
                Pillola(valore: "\(riepilogo.giorniCompletiTotali)", etichetta: "complete days")
                Pillola(valore: Formati.percentuale(riepilogo.finestra7.frazioneMedia),
                        etichetta: "last 7 days")
                Pillola(valore: "\(riepilogo.eventiTotali)", etichetta: "events")
            }
            if !riepilogo.giornate.isEmpty {
                Chart(riepilogo.giornate.suffix(42)) { g in
                    BarMark(x: .value("Day", g.giorno, unit: .day),
                            y: .value("Coverage", g.frazione))
                    .foregroundStyle(g.completa ? Color.accentColor : Color.orange.opacity(0.75))
                    .cornerRadius(2)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = v.as(Double.self) { Text(verbatim: Formati.percentuale(d)) }
                        }
                    }
                }
                .frame(height: 110)
            }
            if riepilogo.giornate.isEmpty {
                Text("Nothing to show yet. Record your first event or your first meal.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if !riepilogo.finestra7.analizzabile {
                Nota(colore: .orange,
                     testo: Text("Coverage over the last 7 days is \(Formati.percentuale(riepilogo.finestra7.frazioneMedia)). Below 70% a period is not analysable, because most days are not observed but only partly known."))
            }
        }
    }

    // MARK: - Forme

    private var distribuzioneForme: some View {
        Sezione("Stool form") {
            Chart(FormaFecale.allCases) { forma in
                BarMark(x: .value("Times", riepilogo.distribuzioneForme[forma.rawValue] ?? 0),
                        y: .value("Form", forma.etichetta(locale)))
                .foregroundStyle(DisegnoForma.colore(forma))
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text(verbatim: "\(riepilogo.distribuzioneForme[forma.rawValue] ?? 0)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: FormaFecale.allCases.map { $0.etichetta(locale) })
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) {
                    AxisValueLabel(horizontalSpacing: 6).font(.caption2)
                }
            }
            .chartXAxis { AxisMarks { AxisGridLine(); AxisValueLabel().font(.caption2) } }
            .chartPlotStyle { $0.padding(.leading, 4) }
            .frame(height: 190)

            let (anormali, osservati) = riepilogo.giorniAnormaliSuOsservati
            if osservati > 0 {
                Text("Days with at least one bowel movement outside the middle range: \(anormali) of \(osservati) observed.")
                    .font(.callout)
            }
            if let e = riepilogo.formaPerEvento.entropiaNormalizzata {
                descriviEntropia(e).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Dolore

    private var andamentoDolore: some View {
        Sezione("Pain, day by day") {
            let serie = esiti.compactMap { e -> (Date, Int)? in
                e.dolorePeggiore.map { (Calendar.current.startOfDay(for: e.giorno), $0) }
            }.sorted { $0.0 < $1.0 }

            Chart {
                ForEach(serie, id: \.0) { g, v in
                    LineMark(x: .value("Day", g, unit: .day), y: .value("Pain", v))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Day", g, unit: .day), y: .value("Pain", v))
                        .symbolSize(22)
                }
                if let m = riepilogo.dolore.media {
                    RuleMark(y: .value("Mean", m))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: 0...10)
            .frame(height: 150)

            if let m = riepilogo.dolore.mediana, let sd = riepilogo.dolore.deviazioneStandard {
                Text("Median \(Formati.decimale(m)), typical swing ±\(Formati.decimale(sd)) points over \(riepilogo.dolore.osservazioni) days.")
                    .font(.callout)
            }
        }
    }

    // MARK: - Variabilità

    private var variabilita: some View {
        Sezione("How much the numbers move on their own") {
            if riepilogo.dolore.osservazioni < Riepilogo.giorniMinimiPerStimareIlRumore {
                Text("At least \(Riepilogo.giorniMinimiPerStimareIlRumore) days with pain recorded are needed to estimate how much it swings by itself. So far there are \(riepilogo.dolore.osservazioni).")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let sd = riepilogo.dolore.deviazioneStandard {
                Text("Your pain moves by about \(Formati.decimale(sd)) points from one day to the next with nothing in particular happening. That is worth knowing before you can say whether anything changes it.")
                    .font(.callout)
            }

            if let c = riepilogo.componentiForma {
                Text("Of the variation in stool form, \(Formati.percentuale(c.icc)) sits between different days and the rest between bowel movements on the same day.")
                    .font(.callout)
                Text("When the between-days share is low, a daily average is mostly noise.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            let acf = riepilogo.autocorrelazioneDolore.contains(where: { $0.r != nil })
                ? riepilogo.autocorrelazioneDolore : riepilogo.autocorrelazioneForma
            if acf.contains(where: { $0.r != nil }) {
                Chart(acf, id: \.ritardo) { a in
                    if let r = a.r {
                        BarMark(x: .value("Distance", "\(a.ritardo)d"),
                                y: .value("Similarity", r))
                            .foregroundStyle(abs(r) >= 0.2 ? Color.orange : Color.accentColor)
                            .cornerRadius(2)
                    }
                }
                .chartYScale(domain: -1...1)
                .frame(height: 110)

                if let pausa = riepilogo.pausaSuggerita {
                    Text("Two days \(pausa) days apart no longer resemble each other appreciably. That is the number a washout between two conditions would have to respect.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Nearby days still resemble each other too much to be treated as independent observations.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Rilevabilità

    @ViewBuilder
    private var rilevabilita: some View {
        if !riepilogo.rilevabilita.isEmpty {
            Sezione("How large an effect would have to be to show up") {
                ForEach(riepilogo.rilevabilita, id: \.giorniTotali) { s in
                    HStack {
                        Text("\(s.periodi) comparisons of \(s.giorniPerPeriodo) days")
                            .font(.callout)
                        Spacer()
                        Text("≥ \(Formati.decimale(s.differenzaMinima)) points")
                            .font(.callout.monospacedDigit().weight(.medium))
                        Text("· \(s.giorniTotali) days")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Computed on the swing measured in your own data, not on values taken from elsewhere. It is the most optimistic estimate possible: it assumes the periods are independent of each other and that you record every day.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Esposizioni

    private var esposizioni: some View {
        Sezione("How often you ate what") {
            if riepilogo.esposizioni.isEmpty {
                Text("No meals recorded yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(riepilogo.esposizioni.prefix(20)) { e in
                    HStack {
                        Text(e.nome).font(.callout)
                        Spacer()
                        Text(verbatim: "\(e.esposizioni)").font(.callout.monospacedDigit())
                        Text("· \(e.giorniDistinti) days")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if riepilogo.esposizioni.count > 20 {
                    Text("and \(riepilogo.esposizioni.count - 20) more.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("This is a count, not a ranking: none of these entries is put in relation with how you felt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Utilità

    private func ricalcola() {
        riepilogo = Riepilogo.costruisci(da: .init(
            eventi: eventi.map { ($0.quando, $0.forma, $0.dolore) },
            pasti: pasti.map { ($0.quando, $0.fascia, $0.risolto) },
            vociPasto: pasti.flatMap { p in
                p.vociOrdinate.compactMap { v in
                    guard let i = v.ingrediente else { return nil }
                    return (p.quando, i.identificativo, i.nome(locale), i.categoria(locale))
                }
            },
            esiti: esiti.map { ($0.giorno, $0.dolorePeggiore) }))
    }

    @ViewBuilder
    private func descriviEntropia(_ e: Double) -> some View {
        if e < 0.4 {
            Text("So far stool form clusters on the same few values: with this little variety, an effect would have little room to show itself.")
        } else if e < 0.7 {
            Text("Stool form uses part of its range.")
        } else {
            Text("Stool form uses its whole range.")
        }
    }
}

// MARK: - Contenitori

struct Sezione<Contenuto: View>: View {
    let titolo: LocalizedStringKey
    @ViewBuilder let contenuto: Contenuto

    init(_ titolo: LocalizedStringKey, @ViewBuilder contenuto: () -> Contenuto) {
        self.titolo = titolo
        self.contenuto = contenuto()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titolo).font(.headline)
            contenuto
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.08)))
    }
}

struct Nota: View {
    var colore: Color = .orange
    let testo: Text

    var body: some View {
        Label { testo.font(.footnote) }
        icon: { Image(systemName: "info.circle.fill") }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(colore.opacity(0.14)))
    }
}
