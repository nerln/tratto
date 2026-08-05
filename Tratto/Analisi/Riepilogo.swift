import Foundation

/// Tutto cio' che l'app ha il diritto di dire sui dati raccolti.
///
/// Il confine e' esplicito e va tenuto: qui dentro non esiste, e non deve mai
/// esistere, nessuna grandezza che metta in relazione un ingrediente con un
/// esito. Le esposizioni si contano, gli esiti si descrivono, e le due cose
/// non si toccano. Fu esattamente quel passaggio, nel 2020, a produrre
/// ottantadue conclusioni su un campione che non ne reggeva nessuna.
nonisolated struct Riepilogo: Sendable {

    struct EsposizioneIngrediente: Sendable, Identifiable, Equatable {
        var identificativo: String
        var nome: String
        var categoria: String
        var esposizioni: Int
        var giorniDistinti: Int
        var ultimaVolta: Date?
        var id: String { identificativo }
    }

    struct DescrittiveEsito: Sendable, Equatable {
        var osservazioni: Int
        var media: Double?
        var mediana: Double?
        var deviazioneStandard: Double?
        var minimo: Double?
        var massimo: Double?
        /// Quanto la variabile usa davvero i suoi livelli: 1 = pienamente,
        /// 0 = e' sempre lo stesso valore. Una variabile schiacciata non ha
        /// spazio per mostrare un effetto, con nessun disegno.
        var entropiaNormalizzata: Double?
    }

    var periodo: (inizio: Date, fine: Date)?
    var giornate: [Copertura.Giornata]
    var finestra7: Copertura.Finestra
    var giorniCompletiTotali: Int

    var eventiTotali: Int
    var distribuzioneForme: [Int: Int]          // forma 1-7 -> conteggio
    var giorniAnormaliSuOsservati: (anormali: Int, osservati: Int)
    var evacuazioniPerGiorno: DescrittiveEsito

    var dolore: DescrittiveEsito
    var formaPerEvento: DescrittiveEsito

    /// Quota della variabilita' della forma che sta fra giorni diversi
    /// invece che fra evacuazioni dello stesso giorno.
    var componentiForma: Statistica.ComponentiVarianza?
    var autocorrelazioneDolore: [Statistica.Autocorrelazione]
    var autocorrelazioneForma: [Statistica.Autocorrelazione]
    var pausaSuggerita: Int?

    var esposizioni: [EsposizioneIngrediente]

    /// Compare solo dopo che c'e' abbastanza serie da stimare il rumore.
    /// Prima di allora qualunque numero di giorni "necessari" sarebbe inventato.
    var rilevabilita: [Statistica.StimaRilevabilita]

    static let giorniMinimiPerStimareIlRumore = 21

    // MARK: - Costruzione

    struct Ingresso: Sendable {
        var eventi: [(quando: Date, forma: Int, dolore: Int?)]
        var pasti: [(quando: Date, fascia: Fascia, risolto: Bool)]
        var vociPasto: [(quando: Date, ingrediente: String, nome: String, categoria: String)]
        var esiti: [(giorno: Date, dolore: Int?)]
        var calendario: Calendar = .current
    }

    static func costruisci(da ingresso: Ingresso) -> Riepilogo {
        let cal = ingresso.calendario

        // --- copertura
        var fasceRisolte: [Date: Set<Fascia>] = [:]
        for p in ingresso.pasti where p.risolto {
            fasceRisolte[cal.startOfDay(for: p.quando), default: []].insert(p.fascia)
        }
        var eventiPerGiorno: [Date: Int] = [:]
        for e in ingresso.eventi {
            eventiPerGiorno[cal.startOfDay(for: e.quando), default: 0] += 1
        }
        let giorniConEsito = Set(ingresso.esiti.compactMap { $0.dolore != nil ? cal.startOfDay(for: $0.giorno) : nil })

        let giornate = Copertura.giornate(fasceRisolte: fasceRisolte,
                                          eventiPerGiorno: eventiPerGiorno,
                                          giorniConEsito: giorniConEsito,
                                          calendario: cal)
        let finestra = Copertura.finestra(giornate, ultimi: 7, calendario: cal)

        // --- eventi
        var distribuzione: [Int: Int] = [:]
        for e in ingresso.eventi { distribuzione[e.forma, default: 0] += 1 }

        var formePerGiorno: [Date: [Double]] = [:]
        for e in ingresso.eventi {
            formePerGiorno[cal.startOfDay(for: e.quando), default: []].append(Double(e.forma))
        }
        let giorniOsservati = formePerGiorno.keys.count
        let giorniAnormali = ingresso.eventi.reduce(into: Set<Date>()) { acc, e in
            if e.forma <= 2 || e.forma >= 6 { acc.insert(cal.startOfDay(for: e.quando)) }
        }.count

        // --- esiti
        let valoriDolore = ingresso.esiti.compactMap { $0.dolore.map(Double.init) }
        let valoriForma = ingresso.eventi.map { Double($0.forma) }

        var serieDolore: [Date: Double] = [:]
        for e in ingresso.esiti {
            if let d = e.dolore { serieDolore[cal.startOfDay(for: e.giorno)] = Double(d) }
        }
        var serieForma: [Date: Double] = [:]
        for (g, v) in formePerGiorno where !v.isEmpty {
            serieForma[g] = v.reduce(0, +) / Double(v.count)
        }

        let acfDolore = Statistica.autocorrelazione(serie: serieDolore, calendario: cal)
        let acfForma = Statistica.autocorrelazione(serie: serieForma, calendario: cal)

        // --- esposizioni
        var perIngrediente: [String: (nome: String, categoria: String, n: Int, giorni: Set<Date>, ultima: Date)] = [:]
        for v in ingresso.vociPasto {
            let g = cal.startOfDay(for: v.quando)
            if var e = perIngrediente[v.ingrediente] {
                e.n += 1; e.giorni.insert(g); e.ultima = Swift.max(e.ultima, v.quando)
                perIngrediente[v.ingrediente] = e
            } else {
                perIngrediente[v.ingrediente] = (v.nome, v.categoria, 1, [g], v.quando)
            }
        }
        let esposizioni = perIngrediente
            .map { EsposizioneIngrediente(identificativo: $0.key, nome: $0.value.nome,
                                          categoria: $0.value.categoria, esposizioni: $0.value.n,
                                          giorniDistinti: $0.value.giorni.count,
                                          ultimaVolta: $0.value.ultima) }
            .sorted { ($0.esposizioni, $1.nome) > ($1.esposizioni, $0.nome) }

        // --- rilevabilita', solo se c'e' serie sufficiente per stimare il rumore
        var rilevabilita: [Statistica.StimaRilevabilita] = []
        if serieDolore.count >= giorniMinimiPerStimareIlRumore,
           let sd = Statistica.deviazioneStandard(Array(serieDolore.values)), sd > 0 {
            for periodi in [4, 6, 8] {
                for giorniPerPeriodo in [3, 5, 7] {
                    if let s = Statistica.differenzaMinimaRilevabile(
                        sdGiornaliera: sd, periodi: periodi, giorniPerPeriodo: giorniPerPeriodo) {
                        rilevabilita.append(s)
                    }
                }
            }
        }

        let tutteLeDate = ingresso.eventi.map(\.quando) + ingresso.pasti.map(\.quando) + ingresso.esiti.map(\.giorno)

        return Riepilogo(
            periodo: tutteLeDate.isEmpty ? nil : (tutteLeDate.min()!, tutteLeDate.max()!),
            giornate: giornate,
            finestra7: finestra,
            giorniCompletiTotali: giornate.filter(\.completa).count,
            eventiTotali: ingresso.eventi.count,
            distribuzioneForme: distribuzione,
            giorniAnormaliSuOsservati: (giorniAnormali, giorniOsservati),
            evacuazioniPerGiorno: descrittive(formePerGiorno.values.map { Double($0.count) }),
            dolore: descrittive(valoriDolore, interi: ingresso.esiti.compactMap(\.dolore)),
            formaPerEvento: descrittive(valoriForma, interi: ingresso.eventi.map(\.forma)),
            componentiForma: Statistica.componentiVarianza(gruppi: Array(formePerGiorno.values)),
            autocorrelazioneDolore: acfDolore,
            autocorrelazioneForma: acfForma,
            pausaSuggerita: Statistica.pausaSuggerita(acfDolore.contains(where: { $0.r != nil }) ? acfDolore : acfForma),
            esposizioni: esposizioni,
            rilevabilita: rilevabilita)
    }

    private static func descrittive(_ x: [Double], interi: [Int]? = nil) -> DescrittiveEsito {
        DescrittiveEsito(
            osservazioni: x.count,
            media: Statistica.media(x),
            mediana: Statistica.mediana(x),
            deviazioneStandard: Statistica.deviazioneStandard(x),
            minimo: x.min(),
            massimo: x.max(),
            entropiaNormalizzata: interi.flatMap(Statistica.entropiaNormalizzata))
    }

    static var vuoto: Riepilogo {
        Riepilogo(periodo: nil, giornate: [],
                  finestra7: Copertura.Finestra(giorni: 7, giorniCompleti: 0, frazioneMedia: 0,
                                                giorniConEsito: 0, giorniConEventi: 0),
                  giorniCompletiTotali: 0, eventiTotali: 0, distribuzioneForme: [:],
                  giorniAnormaliSuOsservati: (0, 0),
                  evacuazioniPerGiorno: DescrittiveEsito(osservazioni: 0, media: nil, mediana: nil,
                                                        deviazioneStandard: nil, minimo: nil,
                                                        massimo: nil, entropiaNormalizzata: nil),
                  dolore: DescrittiveEsito(osservazioni: 0, media: nil, mediana: nil,
                                           deviazioneStandard: nil, minimo: nil, massimo: nil,
                                           entropiaNormalizzata: nil),
                  formaPerEvento: DescrittiveEsito(osservazioni: 0, media: nil, mediana: nil,
                                                  deviazioneStandard: nil, minimo: nil, massimo: nil,
                                                  entropiaNormalizzata: nil),
                  componentiForma: nil, autocorrelazioneDolore: [], autocorrelazioneForma: [],
                  pausaSuggerita: nil, esposizioni: [], rilevabilita: [])
    }
}
