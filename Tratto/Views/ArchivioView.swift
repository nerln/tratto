import SwiftUI
import Charts

/// Il diario del 2020, in sola lettura.
///
/// Non entra nel database dell'app, non si somma ai dati nuovi e non viene
/// convertito. La sua scala della consistenza va da 0 a 5 e cresce in modo
/// monotono, con lo 0 come valore peggiore; quella di oggi ha sette livelli e
/// l'ottimo al centro. Non esiste una conversione fra le due, e inventarne una
/// produrrebbe una serie storica che sembra continua senza esserlo.
///
/// Serve a due cose: aver recuperato quel lavoro, e aver seminato il catalogo
/// degli ingredienti con quello che mangiava davvero.
struct ArchivioView: View {
    private let archivio = Archivio2020.daBundle()

    var body: some View {
        ScrollView {
            if let a = archivio {
                VStack(alignment: .leading, spacing: 20) {
                    intestazione(a)
                    avviso(a)
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
                Text("Archivio non disponibile.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle("Archivio 2020")
    }

    private func intestazione(_ a: Archivio2020) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(a.sottotitolo).font(.headline)
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
        let stile = Date.FormatStyle(date: .long, time: .omitted).locale(Formati.italiano)
        return "dal \(da.formatted(stile)) al \(al.formatted(stile))"
    }

    private func avviso(_ a: Archivio2020) -> some View {
        Nota(colore: .orange, testo: a.avviso)
    }

    private func numeri(_ a: Archivio2020) -> some View {
        Sezione("In cifre") {
            let c = a.conteggi
            HStack(spacing: 10) {
                Pillola(valore: "\(c.giorniCoperti)", etichetta: "giorni su \(c.giorniDiCalendario)")
                Pillola(valore: "\(c.eventi)", etichetta: "eventi")
                Pillola(valore: "\(c.pasti)", etichetta: "pasti")
            }
            HStack(spacing: 10) {
                Pillola(valore: "\(c.alimenti)", etichetta: "alimenti")
                Pillola(valore: "\(c.condimenti)", etichetta: "condimenti")
                Pillola(valore: "\(c.portate)", etichetta: "portate")
            }
            Text("Le due anagrafiche erano separate ma si sovrapponevano: carota, tonno, "
                 + "parmigiano, finocchio, salsiccia e uova comparivano in tutte e due. "
                 + "Nel catalogo di oggi sono una voce sola.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func consistenza(_ a: Archivio2020) -> some View {
        Sezione("Consistenza, scala 0-5 del 2020") {
            let d = a.distribuzioneConsistenza
            Chart(0...5, id: \.self) { livello in
                BarMark(x: .value("Livello", "\(livello)"),
                        y: .value("Volte", d[livello] ?? 0))
                .foregroundStyle(Color.brown.opacity(0.8))
                .cornerRadius(3)
            }
            .frame(height: 130)
            Text("Lo 0 era il valore peggiore e il 5 il migliore. Tre quarti delle osservazioni "
                 + "stanno su due livelli vicini: la scala veniva usata poco più che a metà.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fastidio(_ a: Archivio2020) -> some View {
        Sezione("Fastidio prima dell'evacuazione, scala 0-5 del 2020") {
            let d = a.distribuzioneFastidio
            Chart(0...5, id: \.self) { livello in
                BarMark(x: .value("Livello", "\(livello)"),
                        y: .value("Volte", d[livello] ?? 0))
                .foregroundStyle(Color.orange.opacity(0.75))
                .cornerRadius(3)
            }
            .frame(height: 130)
            Text("Qui lo 0 era il valore migliore: le due scale del 2020 andavano in direzioni opposte.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fasce(_ a: Archivio2020) -> some View {
        Sezione("Quali pasti venivano registrati") {
            Chart(a.pastiPerFascia, id: \.0) { fascia, n in
                BarMark(x: .value("Volte", n), y: .value("Fascia", fascia))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                    .cornerRadius(3)
            }
            .frame(height: 170)
            Text("Su 59 giorni, la colazione compare 25 volte e lo spuntino del mattino una sola. "
                 + "Non è disattenzione: un evento in bagno si ricorda, una colazione uguale a tutte "
                 + "le altre no. È il motivo per cui oggi si può rispondere «niente» con un tocco.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func qualita(_ a: Archivio2020) -> some View {
        Sezione("Cosa è emerso rileggendo i dati") {
            ForEach(a.qualita) { q in
                HStack {
                    Text(q.descrizione).font(.callout)
                    Spacer()
                    Text("\(q.conteggio)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metodo: some View {
        Sezione("Perché quei risultati non reggevano") {
            VStack(alignment: .leading, spacing: 10) {
                Riga("Il punteggio giornaliero veniva assegnato a tutti gli alimenti mangiati "
                     + "quel giorno. Due cibi mangiati sempre insieme non si possono distinguere "
                     + "in nessun modo, con nessun calcolo.")
                Riga("Il punteggio veniva poi «validato» correlandolo con la consistenza media e "
                     + "con il fastidio medio. Ma era calcolato proprio a partire da quei due "
                     + "numeri: la correlazione di 0,84 era il punteggio che correlava con sé stesso.")
                Riga("Ottantatré alimenti venivano confrontati senza nessuna correzione per il "
                     + "numero dei confronti, e solo sette di loro comparivano in almeno dieci pasti.")
                Riga("Solo 26 giorni su 68 avevano almeno tre pasti registrati. Negli altri, "
                     + "l'alimentazione era in gran parte ignota.")
            }
        }
    }

    private func Riga(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 7)
            Text(t).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
