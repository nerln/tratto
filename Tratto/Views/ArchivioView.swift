import SwiftUI
import Charts

/// Il diario del 2020, in sola lettura.
///
/// Non entra nel database dell'app, non si somma ai dati nuovi e non viene
/// convertito. La sua scala della consistenza va da 0 a 5 e cresce in modo
/// monotono, con lo 0 come valore peggiore; quella di oggi ha sette livelli e
/// l'ottimo al centro. Non esiste una conversione fra le due, e inventarne una
/// produrrebbe una serie storica che sembra continua senza esserlo.
struct ArchivioView: View {
    private let archivio = Archivio2020.daBundle()

    var body: some View {
        ScrollView {
            if let a = archivio {
                VStack(alignment: .leading, spacing: 20) {
                    intestazione(a)
                    Nota(colore: .orange, testo: Text("These numbers use different scales from the ones in use now and are not comparable. «Consistency» ran from 0 to 5 with 0 as the worst value and rose monotonically: it is not the seven-level scale used today, whose best value sits in the middle. It is not converted, it enters no calculation, and it is never added to new data. The period also falls in the months right after lockdown, with hours, diet and stress that are hard to repeat."))
                    numeri(a)
                    consistenza(a)
                    fastidio(a)
                    fasce(a)
                    qualita(a)
                    metodo
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            } else {
                Text("Archive not available.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle("2020 archive")
    }

    private func intestazione(_ a: Archivio2020) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Science coursework, May–July 2020").font(.headline)
            if let periodo = periodoLeggibile(a) {
                Text(periodo).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Le date arrivano dal file in forma ISO: qui vanno lette da una persona.
    private func periodoLeggibile(_ a: Archivio2020) -> String? {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        guard let da = a.periodo.from.flatMap(iso.date(from:)),
              let al = a.periodo.to.flatMap(iso.date(from:)) else { return nil }
        return String(localized: "from \(da.formatted(date: .long, time: .omitted)) to \(al.formatted(date: .long, time: .omitted))")
    }

    private func numeri(_ a: Archivio2020) -> some View {
        Sezione("In numbers") {
            let c = a.conteggi
            HStack(spacing: 10) {
                Pillola(valore: "\(c.giorniCoperti)", etichetta: "days of \(c.giorniDiCalendario)")
                Pillola(valore: "\(c.eventi)", etichetta: "events")
                Pillola(valore: "\(c.pasti)", etichetta: "meals")
            }
            HStack(spacing: 10) {
                Pillola(valore: "\(c.alimenti)", etichetta: "foods")
                Pillola(valore: "\(c.condimenti)", etichetta: "condiments")
                Pillola(valore: "\(c.portate)", etichetta: "courses")
            }
            Text("The two lists were kept separate but overlapped: carrot, tuna, parmesan, fennel, sausage and eggs appeared in both. In today's catalogue they are a single entry.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func consistenza(_ a: Archivio2020) -> some View {
        Sezione("Consistency, the 0-5 scale of 2020") {
            let d = a.distribuzioneConsistenza
            Chart(0...5, id: \.self) { livello in
                BarMark(x: .value("Level", "\(livello)"),
                        y: .value("Times", d[livello] ?? 0))
                .foregroundStyle(Color.brown.opacity(0.8))
                .cornerRadius(3)
            }
            .frame(height: 130)
            Text("0 was the worst value and 5 the best. Three quarters of the observations sit on two adjacent levels: the scale was used little more than halfway.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fastidio(_ a: Archivio2020) -> some View {
        Sezione("Discomfort before a bowel movement, the 0-5 scale of 2020") {
            let d = a.distribuzioneFastidio
            Chart(0...5, id: \.self) { livello in
                BarMark(x: .value("Level", "\(livello)"),
                        y: .value("Times", d[livello] ?? 0))
                .foregroundStyle(Color.orange.opacity(0.75))
                .cornerRadius(3)
            }
            .frame(height: 130)
            Text("Here 0 was the best value: the two scales of 2020 ran in opposite directions.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fasce(_ a: Archivio2020) -> some View {
        Sezione("Which meals actually got recorded") {
            Chart(a.pastiPerFascia, id: \.chiave) { voce in
                BarMark(x: .value("Times", voce.conteggio),
                        y: .value("Slot", voce.etichetta))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                    .cornerRadius(3)
            }
            .frame(height: 170)
            Text("Over 59 days, breakfast appears 25 times and the morning snack once. That is not carelessness: a trip to the bathroom is memorable, a breakfast identical to every other one is not. It is why today you can answer «nothing» with one tap.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func qualita(_ a: Archivio2020) -> some View {
        Sezione("What came up on re-reading the data") {
            ForEach(a.qualita) { q in
                HStack {
                    Text(LocalizedStringKey(q.chiaveDescrizione)).font(.callout)
                    Spacer()
                    Text(verbatim: "\(q.conteggio)")
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metodo: some View {
        Sezione("Why those results did not hold") {
            VStack(alignment: .leading, spacing: 10) {
                Riga(Text("The daily score was assigned to every food eaten that day. Two foods always eaten together cannot be told apart, by any calculation."))
                Riga(Text("The score was then «validated» by correlating it with mean consistency and mean discomfort. But it was computed from those two numbers: the correlation of 0.84 was the score correlating with itself."))
                Riga(Text("Eighty-three foods were compared with no correction for the number of comparisons, and only seven of them appeared in at least ten meals."))
                Riga(Text("Only 26 days out of 68 had at least three meals recorded. On the rest, what was eaten was largely unknown."))
            }
        }
    }

    private func Riga(_ t: Text) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 7)
            t.font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
