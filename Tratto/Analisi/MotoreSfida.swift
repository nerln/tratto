import Foundation

/// Programmazione e lettura di un confronto a blocchi.
///
/// Tutto quello che sta qui dentro è funzione pura: la vista passa i dati e
/// riceve il risultato. Serve perché questo è il pezzo in cui un errore non
/// produce un crash ma un numero sbagliato che sembra giusto.
nonisolated enum MotoreSfida {

    // MARK: - Programmazione

    /// Sequenza a coppie AB/BA con l'ordine dentro ogni coppia deciso dal seme.
    ///
    /// Le coppie servono perché il confronto è appaiato: ogni blocco bersaglio
    /// ha il suo blocco di confronto vicino nel tempo, così una deriva lenta
    /// (una stagione, un periodo di lavoro) colpisce entrambi allo stesso modo.
    /// L'ordine dentro la coppia si alterna a caso per non far coincidere la
    /// condizione con la posizione nel tempo.
    static func sequenza(coppie: Int, seme: UInt64) -> [CondizioneBlocco] {
        var stato = seme == 0 ? 0x9E37_79B9_7F4A_7C15 : seme
        func prossimo() -> UInt64 {
            stato ^= stato << 13; stato ^= stato >> 7; stato ^= stato << 17
            return stato
        }
        var esito: [CondizioneBlocco] = []
        for _ in 0..<coppie {
            if prossimo() % 2 == 0 {
                esito.append(.bersaglio); esito.append(.controllo)
            } else {
                esito.append(.controllo); esito.append(.bersaglio)
            }
        }
        return esito
    }

    struct BloccoProgrammato: Sendable, Equatable {
        var indice: Int
        var condizione: CondizioneBlocco
        var dal: Date
        var al: Date
    }

    static func programma(coppie: Int, giorniPerBlocco: Int, giorniDiPausa: Int,
                          inizio: Date, seme: UInt64,
                          calendario: Calendar = .current) -> [BloccoProgrammato] {
        let condizioni = sequenza(coppie: coppie, seme: seme)
        var esito: [BloccoProgrammato] = []
        var giorno = calendario.startOfDay(for: inizio)
        for (i, c) in condizioni.enumerated() {
            guard let fine = calendario.date(byAdding: .day, value: giorniPerBlocco - 1, to: giorno)
            else { break }
            esito.append(BloccoProgrammato(indice: i, condizione: c, dal: giorno, al: fine))
            guard let prossimo = calendario.date(byAdding: .day,
                                                 value: giorniPerBlocco + giorniDiPausa,
                                                 to: giorno) else { break }
            giorno = prossimo
        }
        return esito
    }

    /// Quanto dura tutto, pause comprese.
    static func giorniTotali(coppie: Int, giorniPerBlocco: Int, giorniDiPausa: Int) -> Int {
        let blocchi = coppie * 2
        return blocchi * giorniPerBlocco + Swift.max(0, blocchi - 1) * giorniDiPausa
    }

    // MARK: - Che cosa si può sperare di vedere

    /// Il quadro da mostrare PRIMA di iniziare.
    ///
    /// Il numero che conta non è la differenza minima rilevabile ma la potenza,
    /// e quasi sempre è deprimente: con sei blocchi e ipotesi bilaterale il test
    /// richiede l'unanimità, quindi anche un bersaglio che peggiora davvero i
    /// sintomi in otto blocchi su dieci ha circa una probabilità su quattro di
    /// essere riconosciuto. Dirlo prima è l'unico modo perché la scelta di
    /// spendere due mesi sia informata.
    struct Fattibilita: Sendable, Equatable {
        var coppie: Int
        var giorniTotali: Int
        var pMinimoRaggiungibile: Double
        /// Quante coppie devono concordare perché il risultato sia significativo.
        var concordanzeNecessarie: Int
        /// Potenza se il bersaglio agisse nel 70%, 80% e 90% delle coppie.
        var potenza70: Double
        var potenza80: Double
        var potenza90: Double
        var raggiungibile: Bool
        /// Quante coppie servirebbero per tollerare almeno una discordanza.
        var coppiePerTollerareUnaDiscordanza: Int
    }

    static func fattibilita(coppie: Int, giorniPerBlocco: Int, giorniDiPausa: Int,
                            unilaterale: Bool, alfa: Double = 0.05) -> Fattibilita {
        let pMin = Swift.min(1, pow(2, 1 - Double(coppie)) * (unilaterale ? 0.5 : 1))
        var necessarie = coppie + 1
        for k in stride(from: coppie, through: (coppie / 2) + 1, by: -1) {
            let coda = (k...coppie).reduce(0.0) { $0 + TestEsatti.binomiale(coppie, $1) }
                / pow(2, Double(coppie))
            let valore = unilaterale ? coda : Swift.min(1, 2 * coda)
            if valore <= alfa { necessarie = k } else { break }
        }
        var tolleranza = 0
        for n in coppie...40 {
            let coda = (n - 1...n).reduce(0.0) { $0 + TestEsatti.binomiale(n, $1) } / pow(2, Double(n))
            let valore = unilaterale ? coda : Swift.min(1, 2 * coda)
            if valore <= alfa { tolleranza = n; break }
        }
        return Fattibilita(
            coppie: coppie,
            giorniTotali: giorniTotali(coppie: coppie, giorniPerBlocco: giorniPerBlocco,
                                       giorniDiPausa: giorniDiPausa),
            pMinimoRaggiungibile: pMin,
            concordanzeNecessarie: Swift.min(necessarie, coppie),
            potenza70: TestEsatti.potenzaTestDeiSegni(blocchi: coppie, probabilitaConcordanza: 0.7,
                                                      alfa: alfa, unilaterale: unilaterale) ?? 0,
            potenza80: TestEsatti.potenzaTestDeiSegni(blocchi: coppie, probabilitaConcordanza: 0.8,
                                                      alfa: alfa, unilaterale: unilaterale) ?? 0,
            potenza90: TestEsatti.potenzaTestDeiSegni(blocchi: coppie, probabilitaConcordanza: 0.9,
                                                      alfa: alfa, unilaterale: unilaterale) ?? 0,
            raggiungibile: pMin <= alfa,
            coppiePerTollerareUnaDiscordanza: tolleranza)
    }

    // MARK: - Lettura

    struct GiornoOsservato: Sendable {
        var giorno: Date
        /// Media del dolore quel giorno, se registrata.
        var dolore: Double?
        /// `true` se almeno un'evacuazione era fuori dall'intervallo centrale.
        var giornataAnormale: Bool?
    }

    struct ValoreBlocco: Sendable, Equatable {
        var indice: Int
        var condizione: CondizioneBlocco
        var valore: Double?
        var giorniUsati: Int
        var giorniScartati: Int
    }

    struct Coppia: Sendable, Equatable {
        var numero: Int
        var bersaglio: Double
        var controllo: Double
        var differenza: Double { bersaglio - controllo }
    }

    enum Verdetto: String, Sendable {
        case coerenteConUnEffetto
        case nessunEffettoRilevabile
        case nonConcludente
        /// Il protocollo di adesso non è quello congelato.
        case protocolloAlterato
        /// Non ci sono abbastanza blocchi chiusi.
        case incompleta

        var chiaveNome: String {
            switch self {
            case .coerenteConUnEffetto: "Consistent with an effect"
            case .nessunEffettoRilevabile: "No detectable effect"
            case .nonConcludente: "Inconclusive"
            case .protocolloAlterato: "Protocol changed after it was frozen"
            case .incompleta: "Not finished yet"
            }
        }
    }

    struct Lettura: Sendable {
        var valori: [ValoreBlocco]
        var coppie: [Coppia]
        var segni: TestEsatti.EsitoSegni?
        var wilcoxon: TestEsatti.EsitoWilcoxon?
        var verdetto: Verdetto
        /// Quante coppie sono andate perse perché uno dei due blocchi non aveva
        /// giorni utilizzabili. È il modo più comune in cui un confronto muore.
        var coppiePerse: Int
    }

    /// Calcola il valore di ogni blocco, scartando i primi giorni.
    static func valori(blocchi: [(indice: Int, condizione: CondizioneBlocco, dal: Date, al: Date)],
                       osservazioni: [GiornoOsservato],
                       esito: EsitoSfida,
                       giorniScartatiInTesta: Int,
                       calendario: Calendar = .current) -> [ValoreBlocco] {
        let perGiorno = Dictionary(osservazioni.map { (calendario.startOfDay(for: $0.giorno), $0) },
                                   uniquingKeysWith: { a, _ in a })
        return blocchi.map { b in
            var giorni: [Date] = []
            var giorno = calendario.startOfDay(for: b.dal)
            let fine = calendario.startOfDay(for: b.al)
            while giorno <= fine {
                giorni.append(giorno)
                guard let p = calendario.date(byAdding: .day, value: 1, to: giorno) else { break }
                giorno = p
            }
            let scartati = Swift.min(giorniScartatiInTesta, Swift.max(0, giorni.count - 1))
            let usabili = giorni.dropFirst(scartati)
            let valori: [Double] = usabili.compactMap { g in
                guard let o = perGiorno[g] else { return nil }
                switch esito {
                case .dolore: return o.dolore
                case .giornateAnormali: return o.giornataAnormale.map { $0 ? 1 : 0 }
                }
            }
            return ValoreBlocco(
                indice: b.indice, condizione: b.condizione,
                valore: valori.isEmpty ? nil : valori.reduce(0, +) / Double(valori.count),
                giorniUsati: valori.count, giorniScartati: scartati)
        }
    }

    /// Appaia i blocchi due a due nell'ordine in cui sono stati programmati.
    static func appaia(_ valori: [ValoreBlocco]) -> (coppie: [Coppia], perse: Int) {
        let ordinati = valori.sorted { $0.indice < $1.indice }
        var coppie: [Coppia] = []
        var perse = 0
        var i = 0
        var numero = 1
        while i + 1 < ordinati.count {
            let a = ordinati[i], b = ordinati[i + 1]
            let bersaglio = a.condizione == .bersaglio ? a : b
            let controllo = a.condizione == .bersaglio ? b : a
            if let vb = bersaglio.valore, let vc = controllo.valore {
                coppie.append(Coppia(numero: numero, bersaglio: vb, controllo: vc))
            } else {
                perse += 1
            }
            numero += 1
            i += 2
        }
        return (coppie, perse)
    }

    static func leggi(blocchi: [(indice: Int, condizione: CondizioneBlocco, dal: Date, al: Date)],
                      osservazioni: [GiornoOsservato],
                      esito: EsitoSfida,
                      direzione: DirezioneIpotesi,
                      pareggi: TestEsatti.Pareggi,
                      giorniScartatiInTesta: Int,
                      coppiePreviste: Int,
                      protocolloValido: Bool,
                      alfa: Double = 0.05,
                      calendario: Calendar = .current) -> Lettura {
        let v = valori(blocchi: blocchi, osservazioni: osservazioni, esito: esito,
                       giorniScartatiInTesta: giorniScartatiInTesta, calendario: calendario)
        let (coppie, perse) = appaia(v)

        guard protocolloValido else {
            return Lettura(valori: v, coppie: coppie, segni: nil, wilcoxon: nil,
                           verdetto: .protocolloAlterato, coppiePerse: perse)
        }
        guard coppie.count >= coppiePreviste else {
            return Lettura(valori: v, coppie: coppie, segni: nil, wilcoxon: nil,
                           verdetto: .incompleta, coppiePerse: perse)
        }

        let differenze = coppie.map(\.differenza)
        let segni = TestEsatti.testDeiSegni(differenze: differenze)
        let wil = TestEsatti.wilcoxon(differenze: differenze, pareggi: pareggi)

        let p = direzione.unilaterale ? wil?.pUnilaterale : wil?.pBilaterale
        let verdetto: Verdetto
        if let p, p <= alfa {
            verdetto = .coerenteConUnEffetto
        } else if let w = wil, w.pMinimoRaggiungibile > alfa {
            // non è che l'effetto non c'è: è che con queste coppie non si
            // poteva vedere in nessun caso
            verdetto = .nonConcludente
        } else {
            verdetto = .nessunEffettoRilevabile
        }

        return Lettura(valori: v, coppie: coppie, segni: segni, wilcoxon: wil,
                       verdetto: verdetto, coppiePerse: perse)
    }
}
