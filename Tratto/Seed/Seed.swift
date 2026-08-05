import Foundation
import SwiftData

// MARK: - Ontologia iniziale

struct SeedOntologia: Decodable, Sendable {
    struct Voce: Decodable, Sendable {
        var id: String
        var nome: String
        var categoria: String
        var gruppi: [String]
        var sinonimi: [String]
        var terminiLegacy2020: [String]
        var esposizioni2020: Int
    }
    var versione: Int
    var origine: String
    var nota: String
    var ingredienti: [Voce]

    static func daBundle(_ bundle: Bundle = .main) -> SeedOntologia? {
        guard let url = bundle.url(forResource: "seed-ontologia", withExtension: "json"),
              let dati = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SeedOntologia.self, from: dati)
    }
}

// MARK: - Archivio 2020, sola lettura

/// Il diario del 2020 non entra nel database dell'app e non ha nessuna
/// relazione con le entita' nuove. Vive qui, in strutture immutabili caricate
/// dal bundle, cosi' la sola lettura e' garantita dal tipo e non dalla
/// disciplina di chi scrive il codice.
struct Archivio2020: Decodable, Sendable {
    struct Pasto: Decodable, Sendable, Identifiable {
        var giorno: String
        var fascia: String
        var termini: [String]
        var canonici: [String]
        var id: String { "\(giorno)-\(fascia)" }
    }
    struct Evento: Decodable, Sendable, Identifiable {
        var quando: String
        var consistenza: Double?
        var fastidio: Double?
        var id: String { quando }
    }
    struct Periodo: Decodable, Sendable {
        var from: String?
        var to: String?
        var calendar_days: Int
    }
    struct Conteggi: Decodable, Sendable {
        var giorniDiCalendario: Int
        var giorniCoperti: Int
        var pasti: Int
        var eventi: Int
        var alimenti: Int
        var condimenti: Int
        var portate: Int
    }
    struct Qualita: Decodable, Sendable, Identifiable {
        var tipo: String
        var conteggio: Int
        var id: String { tipo }

        var descrizione: String {
            switch tipo {
            case "missing_type": "alimenti senza categoria"
            case "missing_value": "valori mancanti negli eventi"
            case "empty_event": "righe di evento vuote, scartate"
            case "dup": "voci duplicate in anagrafica"
            case "orphan_cond", "orphan_food", "orphan_group", "orphan_course":
                "riferimenti a voci inesistenti"
            case "bad_date": "date non interpretabili"
            case "bad_num": "valori non numerici"
            default: tipo
            }
        }
    }

    var versione: Int
    var titolo: String
    var sottotitolo: String
    var avviso: String
    var periodo: Periodo
    var conteggi: Conteggi
    var qualita: [Qualita]
    var pasti: [Pasto]
    var eventi: [Evento]

    static func daBundle(_ bundle: Bundle = .main) -> Archivio2020? {
        guard let url = bundle.url(forResource: "archivio-2020", withExtension: "json"),
              let dati = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Archivio2020.self, from: dati)
    }

    /// Distribuzione della vecchia scala 0-5, mostrata come tale e mai convertita.
    var distribuzioneConsistenza: [Int: Int] {
        var d: [Int: Int] = [:]
        for e in eventi { if let c = e.consistenza { d[Int(c), default: 0] += 1 } }
        return d
    }

    var distribuzioneFastidio: [Int: Int] {
        var d: [Int: Int] = [:]
        for e in eventi { if let f = e.fastidio { d[Int(f), default: 0] += 1 } }
        return d
    }

    var pastiPerFascia: [(String, Int)] {
        let ordine = ["Colazione", "Spuntino_mattina", "Pranzo",
                      "Spuntino_pomeriggio", "Cena", "Spuntino_cena"]
        var d: [String: Int] = [:]
        for p in pasti { d[p.fascia, default: 0] += 1 }
        return ordine.compactMap { f in d[f].map { (f.replacingOccurrences(of: "_", with: " "), $0) } }
    }
}

// MARK: - Applicazione del seed

@MainActor
enum Avvio {

    /// Popola l'ontologia al primo avvio e la aggiorna se il file del bundle
    /// e' piu' recente. Non tocca mai le voci create dall'utente.
    static func preparaSeServe(contesto: ModelContext) throws {
        let impostazioni = try impostazioniCorrenti(contesto: contesto)
        guard let seed = SeedOntologia.daBundle() else { return }
        guard impostazioni.versioneSeed < seed.versione else { return }

        let esistenti = try contesto.fetch(FetchDescriptor<Ingrediente>())
        var perId = Dictionary(uniqueKeysWithValues: esistenti.map { ($0.identificativo, $0) })

        for voce in seed.ingredienti {
            if let g = perId[voce.id] {
                guard !g.creatoDallUtente else { continue }
                g.nome = voce.nome
                g.categoria = voce.categoria
                g.gruppi = voce.gruppi
                g.sinonimi = voce.sinonimi
                g.terminiLegacy = voce.terminiLegacy2020
                g.esposizioni2020 = voce.esposizioni2020
            } else {
                let nuovo = Ingrediente(identificativo: voce.id, nome: voce.nome,
                                        categoria: voce.categoria, gruppi: voce.gruppi,
                                        sinonimi: voce.sinonimi,
                                        terminiLegacy: voce.terminiLegacy2020,
                                        esposizioni2020: voce.esposizioni2020)
                contesto.insert(nuovo)
                perId[voce.id] = nuovo
            }
        }
        impostazioni.versioneSeed = seed.versione
        impostazioni.seedApplicato = true
        try contesto.save()
    }

    static func impostazioniCorrenti(contesto: ModelContext) throws -> Impostazioni {
        let trovate = try contesto.fetch(FetchDescriptor<Impostazioni>())
        if let prima = trovate.first { return prima }
        let nuove = Impostazioni()
        contesto.insert(nuove)
        try contesto.save()
        return nuove
    }
}
