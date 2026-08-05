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
    @Query private var eventi: [EventoIntestinale]
    @Query private var pasti: [Pasto]
    @Query private var esiti: [EsitoGiornaliero]
    @Query private var ingredienti: [Ingrediente]

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
        .navigationTitle("Raccolta")
        .onAppear(perform: ricalcola)
        .onChange(of: eventi.count) { ricalcola() }
        .onChange(of: pasti.count) { ricalcola() }
        .onChange(of: esiti.count) { ricalcola() }
    }

    // MARK: - Copertura

    private var copertura: some View {
        Sezione("Copertura") {
            HStack(spacing: 10) {
                Pillola(valore: "\(riepilogo.giorniCompletiTotali)", etichetta: "giorni completi")
                Pillola(valore: percentuale(riepilogo.finestra7.frazioneMedia), etichetta: "ultimi 7 giorni")
                Pillola(valore: "\(riepilogo.eventiTotali)", etichetta: "eventi")
            }
            if !riepilogo.giornate.isEmpty {
                Chart(riepilogo.giornate.suffix(42)) { g in
                    BarMark(x: .value("Giorno", g.giorno, unit: .day),
                            y: .value("Copertura", g.frazione))
                    .foregroundStyle(g.completa ? Color.accentColor : Color.orange.opacity(0.75))
                    .cornerRadius(2)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { v in
                        AxisGridLine()
                        AxisValueLabel { if let d = v.as(Double.self) { Text(percentuale(d)) } }
                    }
                }
                .frame(height: 110)
            }
            if riepilogo.giornate.isEmpty {
                Text("Non c'è ancora niente da mostrare. Registra il primo evento o il primo pasto.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if !riepilogo.finestra7.analizzabile {
                Nota(colore: .orange,
                     testo: "Negli ultimi 7 giorni la copertura è \(percentuale(riepilogo.finestra7.frazioneMedia)): "
                          + "sotto il 70% un periodo non è analizzabile, perché la maggior parte delle "
                          + "giornate non è osservata ma solo parzialmente nota.")
            }
        }
    }

    // MARK: - Forme

    private var distribuzioneForme: some View {
        Sezione("Forma delle feci") {
            Chart(FormaFecale.allCases) { forma in
                BarMark(x: .value("Volte", riepilogo.distribuzioneForme[forma.rawValue] ?? 0),
                        y: .value("Forma", forma.etichetta))
                .foregroundStyle(DisegnoForma.colore(forma))
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text("\(riepilogo.distribuzioneForme[forma.rawValue] ?? 0)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: FormaFecale.allCases.map(\.etichetta))
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
                Text("Giornate con almeno un'evacuazione fuori dall'intervallo centrale: "
                     + "\(anormali) su \(osservati) osservate.")
                    .font(.callout)
            }
            if let e = riepilogo.formaPerEvento.entropiaNormalizzata {
                Text(descriviEntropia(e, cosa: "la forma"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Dolore

    private var andamentoDolore: some View {
        Sezione("Dolore, giorno per giorno") {
            let serie = esiti.compactMap { e -> (Date, Int)? in
                e.dolorePeggiore.map { (Calendar.current.startOfDay(for: e.giorno), $0) }
            }.sorted { $0.0 < $1.0 }

            Chart {
                ForEach(serie, id: \.0) { g, v in
                    LineMark(x: .value("Giorno", g, unit: .day), y: .value("Dolore", v))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Giorno", g, unit: .day), y: .value("Dolore", v))
                        .symbolSize(22)
                }
                if let m = riepilogo.dolore.media {
                    RuleMark(y: .value("Media", m))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: 0...10)
            .frame(height: 150)

            if let m = riepilogo.dolore.mediana, let sd = riepilogo.dolore.deviazioneStandard {
                Text("Mediana \(numero(m)), oscillazione tipica ±\(numero(sd)) punti "
                     + "su \(Formati.giorni(riepilogo.dolore.osservazioni)).")
                    .font(.callout)
            }
        }
    }

    // MARK: - Variabilità

    private var variabilita: some View {
        Sezione("Quanto oscillano i numeri") {
            if riepilogo.dolore.osservazioni < Riepilogo.giorniMinimiPerStimareIlRumore {
                Text("Servono almeno \(Formati.giorni(Riepilogo.giorniMinimiPerStimareIlRumore)) con il dolore "
                     + "segnato per stimare quanto oscilla da solo. Finora sono "
                     + "\(riepilogo.dolore.osservazioni).")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let sd = riepilogo.dolore.deviazioneStandard {
                Text("Il dolore cambia di circa \(numero(sd)) punti da un giorno all'altro "
                     + "senza che sia successo niente di particolare. Serve saperlo prima di "
                     + "poter dire se qualcosa lo cambia davvero.")
                    .font(.callout)
            }

            if let c = riepilogo.componentiForma {
                Text("Della variabilità della forma, \(Formati.percentualeConArticolo(c.icc)) sta fra "
                     + "giorni diversi e il resto fra evacuazioni dello stesso giorno.")
                    .font(.callout)
                Text("Quando la quota fra giorni è bassa, la media di una giornata è per lo più rumore.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            let acf = riepilogo.autocorrelazioneDolore.contains(where: { $0.r != nil })
                ? riepilogo.autocorrelazioneDolore : riepilogo.autocorrelazioneForma
            if acf.contains(where: { $0.r != nil }) {
                Chart(acf, id: \.ritardo) { a in
                    if let r = a.r {
                        BarMark(x: .value("Distanza", "\(a.ritardo)g"), y: .value("Somiglianza", r))
                            .foregroundStyle(abs(r) >= 0.2 ? Color.orange : Color.accentColor)
                            .cornerRadius(2)
                    }
                }
                .chartYScale(domain: -1...1)
                .frame(height: 110)

                if let pausa = riepilogo.pausaSuggerita {
                    Text("Due giorni distanti \(Formati.giorni(pausa)) non si somigliano più in modo "
                         + "apprezzabile. È il primo numero che, un domani, direbbe quanto deve durare "
                         + "una pausa fra due condizioni da confrontare.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("I giorni vicini si somigliano ancora troppo perché si possano trattare "
                         + "come osservazioni indipendenti.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Rilevabilità

    @ViewBuilder
    private var rilevabilita: some View {
        if !riepilogo.rilevabilita.isEmpty {
            Sezione("Quanto dovrebbe essere grande un effetto per potersi vedere") {
                ForEach(riepilogo.rilevabilita, id: \.giorniTotali) { s in
                    HStack {
                        Text("\(s.periodi) confronti da \(Formati.giorni(s.giorniPerPeriodo))")
                            .font(.callout)
                        Spacer()
                        Text("≥ \(numero(s.differenzaMinima)) punti")
                            .font(.callout.monospacedDigit().weight(.medium))
                        Text("· \(Formati.giorni(s.giorniTotali))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Calcolato sull'oscillazione misurata nei tuoi dati, non su valori presi altrove. "
                     + "È la stima più ottimistica possibile: dà per scontato che i periodi siano "
                     + "indipendenti fra loro e che tu registri tutti i giorni.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Esposizioni

    private var esposizioni: some View {
        Sezione("Quante volte hai mangiato che cosa") {
            if riepilogo.esposizioni.isEmpty {
                Text("Ancora nessun pasto registrato.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(riepilogo.esposizioni.prefix(20)) { e in
                    HStack {
                        Text(e.nome).font(.callout)
                        Spacer()
                        Text("\(e.esposizioni)").font(.callout.monospacedDigit())
                        Text("· \(Formati.giorni(e.giorniDistinti))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if riepilogo.esposizioni.count > 20 {
                    Text("e altri \(riepilogo.esposizioni.count - 20).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("È un conteggio, non una classifica: nessuna di queste voci è messa in "
                     + "relazione con come è andata.")
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
                    return (p.quando, i.identificativo, i.nome, i.categoria)
                }
            },
            esiti: esiti.map { ($0.giorno, $0.dolorePeggiore) }))
    }

    private func percentuale(_ x: Double) -> String { Formati.percentuale(x) }
    private func numero(_ x: Double) -> String { Formati.decimale(x) }
    private func descriviEntropia(_ e: Double, cosa: String) -> String {
        if e < 0.4 {
            return "Finora \(cosa) si concentra quasi sempre sugli stessi valori: con così poca "
                 + "varietà, un eventuale effetto avrebbe poco spazio per manifestarsi."
        } else if e < 0.7 {
            return "\(cosa.prefix(1).uppercased() + cosa.dropFirst()) usa una parte dei suoi livelli."
        }
        return "\(cosa.prefix(1).uppercased() + cosa.dropFirst()) usa bene tutta la sua scala."
    }
}

// MARK: - Contenitori

struct Sezione<Contenuto: View>: View {
    let titolo: String
    @ViewBuilder let contenuto: Contenuto

    init(_ titolo: String, @ViewBuilder contenuto: () -> Contenuto) {
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
    let testo: String

    var body: some View {
        Label { Text(testo).font(.footnote) }
        icon: { Image(systemName: "info.circle.fill") }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(colore.opacity(0.14)))
    }
}
