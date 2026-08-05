#if DEBUG
import Foundation
import SwiftData

/// Imbragatura per le anteprime e per gli screenshot.
///
/// Esiste solo nelle build di sviluppo: in `Release` questo file non viene
/// compilato affatto, quindi non c'è nessuna via per far comparire dati finti
/// in un archivio vero.
///
/// Argomenti riconosciuti al lancio:
///   --scheda=<adesso|giornata|raccolta|archivio|esporta>
///   --dati-esempio[=<giorni>]     popola l'archivio con dati verosimili
///   --azzera                      svuota l'archivio prima di popolarlo
enum Anteprime {

    static var attive: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--scheda=") || $0.hasPrefix("--dati-esempio") }
    }

    static var schedaRichiesta: Scheda? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--scheda=") })
        else { return nil }
        return Scheda(rawValue: String(arg.dropFirst("--scheda=".count)))
    }

    static var giorniRichiesti: Int? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--dati-esempio") })
        else { return nil }
        guard let uguale = arg.firstIndex(of: "=") else { return 40 }
        return Int(arg[arg.index(after: uguale)...]) ?? 40
    }

    static var deveAzzerare: Bool {
        ProcessInfo.processInfo.arguments.contains("--azzera")
    }

    /// Generatore deterministico: gli screenshot devono essere riproducibili.
    private struct Casuale {
        var stato: UInt64
        mutating func prossimo() -> UInt64 {
            stato ^= stato << 13; stato ^= stato >> 7; stato ^= stato << 17
            return stato
        }
        mutating func intero(_ intervallo: ClosedRange<Int>) -> Int {
            let ampiezza = UInt64(intervallo.upperBound - intervallo.lowerBound + 1)
            return intervallo.lowerBound + Int(prossimo() % ampiezza)
        }
        mutating func probabilita(_ p: Double) -> Bool {
            Double(prossimo() % 1000) / 1000.0 < p
        }
    }

    @MainActor
    static func popola(contesto: ModelContext, giorni: Int) throws {
        if deveAzzerare {
            for e in try contesto.fetch(FetchDescriptor<EventoIntestinale>()) { contesto.delete(e) }
            for p in try contesto.fetch(FetchDescriptor<Pasto>()) { contesto.delete(p) }
            for e in try contesto.fetch(FetchDescriptor<EsitoGiornaliero>()) { contesto.delete(e) }
            for c in try contesto.fetch(FetchDescriptor<ContestoGiornaliero>()) { contesto.delete(c) }
            try contesto.save()
        }
        guard try contesto.fetch(FetchDescriptor<EventoIntestinale>()).isEmpty else { return }

        let ingredienti = try contesto.fetch(FetchDescriptor<Ingrediente>())
        guard !ingredienti.isEmpty else { return }
        let perId = Dictionary(ingredienti.map { ($0.identificativo, $0) }, uniquingKeysWith: { a, _ in a })

        // le voci che nel 2020 comparivano davvero piu' spesso
        let colazione = ["latte_senza_lattosio", "riso_soffiato", "mela"]
        let pranzi = [["riso", "zucchina", "olio_di_oliva"],
                      ["pasta_integrale", "pomodoro", "parmigiano", "olio_di_oliva"],
                      ["riso", "pollo", "carota", "limone"]]
        let cene = [["pollo", "insalata", "olio_di_oliva"],
                    ["pane_di_semola", "parmigiano", "pomodoro"],
                    ["salsiccia", "patata", "cipolla"],
                    ["riso", "finocchio", "olio_di_oliva", "limone"]]

        var rng = Casuale(stato: 0x5EED_1234_ABCD_0001)
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: .now)

        for indietro in stride(from: giorni - 1, through: 0, by: -1) {
            guard let giorno = cal.date(byAdding: .day, value: -indietro, to: oggi) else { continue }

            // qualche giornata incompleta, perche' e' cosi' che va davvero
            let completa = rng.probabilita(0.78)

            func inserisciPasto(_ fascia: Fascia, _ voci: [String]) {
                var c = cal.dateComponents([.year, .month, .day], from: giorno)
                c.hour = fascia.oraTipica
                c.minute = rng.intero(0...50)
                let quando = cal.date(from: c) ?? giorno
                let risolti = voci.compactMap { perId[$0] }
                let pasto = Pasto(quando: quando, fascia: fascia, stato: .registrato,
                                  fonte: .dettatura,
                                  testoGrezzo: risolti.map(\.nome).joined(separator: ", ").lowercased())
                contesto.insert(pasto)
                for i in risolti {
                    let v = VoceDiPasto(ingrediente: i, quantita: .normale, testoOriginale: i.nome)
                    v.pasto = pasto
                    contesto.insert(v)
                }
            }

            if completa || rng.probabilita(0.5) {
                inserisciPasto(.colazione, colazione)
            } else {
                var c = cal.dateComponents([.year, .month, .day], from: giorno)
                c.hour = Fascia.colazione.oraTipica
                contesto.insert(Pasto(quando: cal.date(from: c) ?? giorno,
                                      fascia: .colazione, stato: .digiuno, fonte: .notifica))
            }
            inserisciPasto(.pranzo, pranzi[rng.intero(0...(pranzi.count - 1))])
            if completa { inserisciPasto(.cena, cene[rng.intero(0...(cene.count - 1))]) }

            // 1-3 evacuazioni, forma concentrata al centro con code
            for _ in 0..<rng.intero(1...3) {
                var c = cal.dateComponents([.year, .month, .day], from: giorno)
                c.hour = rng.intero(6...22)
                c.minute = rng.intero(0...59)
                let sorte = rng.intero(1...100)
                let forma = switch sorte {
                case 1...8: 2
                case 9...28: 3
                case 29...62: 4
                case 63...84: 5
                case 85...96: 6
                default: 7
                }
                contesto.insert(EventoIntestinale(
                    quando: cal.date(from: c) ?? giorno, forma: forma,
                    urgenza: rng.probabilita(0.5) ? rng.intero(0...7) : nil,
                    dolore: rng.probabilita(0.4) ? rng.intero(0...6) : nil))
            }

            if rng.probabilita(0.86) {
                contesto.insert(EsitoGiornaliero(giorno: giorno,
                                                 dolorePeggiore: rng.intero(0...7),
                                                 gonfiore: rng.intero(0...6)))
                let ctx = ContestoGiornaliero(giorno: giorno)
                ctx.oreSonno = Double(rng.intero(11...18)) / 2
                ctx.stress = rng.intero(0...8)
                ctx.caffe = rng.intero(0...3)
                ctx.alcol = rng.probabilita(0.2)
                ctx.esercizio = rng.probabilita(0.35)
                contesto.insert(ctx)
            }
        }
        try contesto.save()
    }
}
#endif
