import Foundation

/// Quanto di una giornata e' effettivamente noto.
///
/// E' la misura che nel 2020 mancava e che spiega il fallimento meglio di
/// qualunque considerazione statistica: su 68 giorni, solo 26 avevano almeno
/// tre pasti registrati. Una giornata con due pasti su sei annotati non e' una
/// giornata osservata, e' una giornata per lo piu' ignota; trattarla come dato
/// e' il modo piu' rapido per costruire conclusioni sul nulla.
///
/// Una fascia conta come risolta anche quando la risposta e' "niente": sapere
/// che non ha mangiato e' informazione, non un buco.
nonisolated enum Copertura {

    struct Giornata: Sendable, Equatable, Identifiable {
        var giorno: Date
        var fasceAttese: Int
        var fasceRisolte: Int
        var eventi: Int
        var haEsito: Bool

        var id: Date { giorno }
        var frazione: Double { fasceAttese > 0 ? Double(fasceRisolte) / Double(fasceAttese) : 0 }
        /// Completa = tutte le fasce attese hanno una risposta.
        var completa: Bool { fasceAttese > 0 && fasceRisolte >= fasceAttese }
    }

    struct Finestra: Sendable, Equatable {
        var giorni: Int
        var giorniCompleti: Int
        var frazioneMedia: Double
        var giorniConEsito: Int
        var giorniConEventi: Int

        /// Sotto questa soglia l'app dichiara il periodo non analizzabile
        /// invece di mostrare numeri che sembrano validi.
        static let sogliaAnalizzabilita = 0.70
        var analizzabile: Bool { frazioneMedia >= Self.sogliaAnalizzabilita }
    }

    /// Costruisce la copertura giorno per giorno su tutto l'intervallo,
    /// includendo i giorni completamente vuoti: un giorno senza niente e' il
    /// dato piu' importante da non nascondere.
    static func giornate(fasceRisolte: [Date: Set<Fascia>],
                         eventiPerGiorno: [Date: Int],
                         giorniConEsito: Set<Date>,
                         da inizio: Date? = nil,
                         a fine: Date? = nil,
                         fasceAttese: [Fascia] = Fascia.attese,
                         calendario: Calendar = .current) -> [Giornata] {
        let chiavi = Set(fasceRisolte.keys)
            .union(eventiPerGiorno.keys)
            .union(giorniConEsito)
        guard let primo = inizio ?? chiavi.min(), let ultimo = fine ?? chiavi.max() else { return [] }

        var risultato: [Giornata] = []
        var giorno = calendario.startOfDay(for: primo)
        let stop = calendario.startOfDay(for: ultimo)
        while giorno <= stop {
            let risolte = fasceRisolte[giorno] ?? []
            risultato.append(Giornata(
                giorno: giorno,
                fasceAttese: fasceAttese.count,
                fasceRisolte: fasceAttese.filter { risolte.contains($0) }.count,
                eventi: eventiPerGiorno[giorno] ?? 0,
                haEsito: giorniConEsito.contains(giorno)))
            guard let prossimo = calendario.date(byAdding: .day, value: 1, to: giorno) else { break }
            giorno = prossimo
        }
        return risultato
    }

    /// Riassunto sugli ultimi `giorni` giorni di calendario a partire da `fine`.
    static func finestra(_ giornate: [Giornata], ultimi giorni: Int = 7,
                         fine: Date = .now, calendario: Calendar = .current) -> Finestra {
        let ultimo = calendario.startOfDay(for: fine)
        guard let primo = calendario.date(byAdding: .day, value: -(giorni - 1), to: ultimo) else {
            return Finestra(giorni: 0, giorniCompleti: 0, frazioneMedia: 0,
                            giorniConEsito: 0, giorniConEventi: 0)
        }
        let dentro = giornate.filter { $0.giorno >= primo && $0.giorno <= ultimo }
        // I giorni assenti dall'elenco contano come copertura zero: non esistono
        // giorni "neutri", o si sa cosa e' successo o non si sa.
        let frazioni = dentro.map(\.frazione)
        let somma = frazioni.reduce(0, +)
        return Finestra(
            giorni: giorni,
            giorniCompleti: dentro.filter(\.completa).count,
            frazioneMedia: somma / Double(giorni),
            giorniConEsito: dentro.filter(\.haEsito).count,
            giorniConEventi: dentro.filter { $0.eventi > 0 }.count)
    }
}
