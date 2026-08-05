import Foundation

/// Produzione dei file da consegnare o da conservare.
///
/// Il formato che serve davvero a una visita è il PDF: nessuno studio in Italia
/// importa oggi un bundle FHIR mandato da un paziente. Il CSV è la via verso R,
/// dove l'analisi vera la fa lui e non l'app. Il JSON è per il backup e per
/// passare i dati fra Mac e telefono come file, senza sincronizzazioni
/// automatiche. FHIR c'è perché lo schema era già quello giusto e costava
/// quasi niente, non perché serva domani.
nonisolated enum Esportazione {

    struct Istantanea: Sendable {
        struct Evento: Sendable {
            var quando: Date
            var forma: Int
            var urgenza: Int?
            var dolore: Int?
            var sangue: Bool
            var note: String
        }
        struct VocePasto: Sendable {
            var quando: Date
            var fascia: String
            var stato: String
            var ingredienteId: String
            var ingredienteNome: String
            var categoria: String
            var quantita: String
            var testoGrezzo: String
        }
        struct Giorno: Sendable {
            var giorno: Date
            var dolore: Int?
            var gonfiore: Int?
            var oreSonno: Double?
            var stress: Int?
            var caffe: Int?
            var alcol: Bool?
            var esercizio: Bool?
            var atipica: Bool
        }
        var eventi: [Evento]
        var pasti: [VocePasto]
        var giorni: [Giorno]
        var riepilogo: Riepilogo
        var codificheEsterne: Bool
    }

    /// I formattatori di Foundation non sono condivisibili fra thread, quindi
    /// se ne crea uno per chiamata: l'export gira una volta ogni tanto e su
    /// poche centinaia di righe, il costo non si nota.
    enum iso {
        static func string(from d: Date) -> String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: d)
        }
    }

    static func giornoISO(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    // MARK: - CSV

    static func csvEventi(_ i: Istantanea) -> String {
        var righe = ["quando,forma_1_7,urgenza_0_10,dolore_0_10,sangue,note"]
        for e in i.eventi.sorted(by: { $0.quando < $1.quando }) {
            righe.append([iso.string(from: e.quando), "\(e.forma)",
                          e.urgenza.map(String.init) ?? "",
                          e.dolore.map(String.init) ?? "",
                          e.sangue ? "1" : "0", campo(e.note)].joined(separator: ","))
        }
        return righe.joined(separator: "\n") + "\n"
    }

    /// Una riga per ingrediente, che è la forma in cui serve a chi analizza.
    static func csvPasti(_ i: Istantanea) -> String {
        var righe = ["quando,fascia,stato,ingrediente_id,ingrediente,categoria,quantita,testo_grezzo"]
        for p in i.pasti.sorted(by: { $0.quando < $1.quando }) {
            righe.append([iso.string(from: p.quando), p.fascia, p.stato,
                          p.ingredienteId, campo(p.ingredienteNome), campo(p.categoria),
                          p.quantita, campo(p.testoGrezzo)].joined(separator: ","))
        }
        return righe.joined(separator: "\n") + "\n"
    }

    static func csvGiorni(_ i: Istantanea) -> String {
        var righe = ["giorno,dolore_0_10,gonfiore_0_10,ore_sonno,stress_0_10,caffe,alcol,esercizio,atipica,fasce_risolte,fasce_attese,eventi"]
        let copertura = Dictionary(uniqueKeysWithValues: i.riepilogo.giornate.map { ($0.giorno, $0) })
        for g in i.giorni.sorted(by: { $0.giorno < $1.giorno }) {
            let c = copertura[Calendar.current.startOfDay(for: g.giorno)]
            var campi: [String] = [giornoISO(g.giorno)]
            campi.append(g.dolore.map { String($0) } ?? "")
            campi.append(g.gonfiore.map { String($0) } ?? "")
            campi.append(g.oreSonno.map { String(format: "%.1f", $0) } ?? "")
            campi.append(g.stress.map { String($0) } ?? "")
            campi.append(g.caffe.map { String($0) } ?? "")
            campi.append(g.alcol.map { $0 ? "1" : "0" } ?? "")
            campi.append(g.esercizio.map { $0 ? "1" : "0" } ?? "")
            campi.append(g.atipica ? "1" : "0")
            campi.append(String(c?.fasceRisolte ?? 0))
            campi.append(String(c?.fasceAttese ?? 0))
            campi.append(String(c?.eventi ?? 0))
            righe.append(campi.joined(separator: ","))
        }
        return righe.joined(separator: "\n") + "\n"
    }

    private static func campo(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - JSON

    static func json(_ i: Istantanea) throws -> Data {
        var eventi: [[String: Any]] = []
        for e in i.eventi.sorted(by: { $0.quando < $1.quando }) {
            var d: [String: Any] = ["quando": iso.string(from: e.quando), "forma": e.forma,
                                    "sangue": e.sangue]
            if let u = e.urgenza { d["urgenza"] = u }
            if let p = e.dolore { d["dolore"] = p }
            if !e.note.isEmpty { d["note"] = e.note }
            eventi.append(d)
        }
        var pasti: [[String: Any]] = []
        for p in i.pasti.sorted(by: { $0.quando < $1.quando }) {
            pasti.append(["quando": iso.string(from: p.quando), "fascia": p.fascia,
                          "stato": p.stato, "ingrediente": p.ingredienteId,
                          "nome": p.ingredienteNome, "categoria": p.categoria,
                          "quantita": p.quantita, "testo": p.testoGrezzo])
        }
        var giorni: [[String: Any]] = []
        for g in i.giorni.sorted(by: { $0.giorno < $1.giorno }) {
            var d: [String: Any] = ["giorno": giornoISO(g.giorno), "atipica": g.atipica]
            if let x = g.dolore { d["dolore"] = x }
            if let x = g.gonfiore { d["gonfiore"] = x }
            if let x = g.oreSonno { d["oreSonno"] = x }
            if let x = g.stress { d["stress"] = x }
            if let x = g.caffe { d["caffe"] = x }
            if let x = g.alcol { d["alcol"] = x }
            if let x = g.esercizio { d["esercizio"] = x }
            giorni.append(d)
        }
        let radice: [String: Any] = [
            "applicazione": "Tratto",
            "versioneFormato": 1,
            "scale": [
                "forma": Concetto.formaFecale.notaPerIlClinico ?? "",
                "dolore": Concetto.dolorePeggiore24h.notaPerIlClinico ?? "",
            ],
            "eventi": eventi, "pasti": pasti, "giorni": giorni,
        ]
        return try JSONSerialization.data(withJSONObject: radice,
                                          options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    // MARK: - FHIR

    /// Bundle di tipo `collection` con una Observation per evento e una per
    /// giornata. Ogni `code` porta sempre la codifica locale; quelle esterne si
    /// aggiungono solo se l'utente le ha attivate, perché SNOMED CT non è
    /// libero in Italia.
    static func fhir(_ i: Istantanea) throws -> Data {
        func code(_ c: Concetto) -> [String: Any] {
            ["coding": c.codifiche(includiEsterne: i.codificheEsterne).map {
                ["system": $0.sistema, "code": $0.codice, "display": $0.etichetta]
            }, "text": c.etichetta]
        }
        var voci: [[String: Any]] = []

        for e in i.eventi.sorted(by: { $0.quando < $1.quando }) {
            var risorsa: [String: Any] = [
                "resourceType": "Observation",
                "status": "final",
                "category": [["coding": [["system": "http://terminology.hl7.org/CodeSystem/observation-category",
                                          "code": "survey", "display": "Survey"]]]],
                "code": code(.formaFecale),
                "effectiveDateTime": iso.string(from: e.quando),
                "valueInteger": e.forma,
            ]
            if let nota = Concetto.formaFecale.notaPerIlClinico {
                risorsa["note"] = [["text": nota]]
            }
            var componenti: [[String: Any]] = []
            if let u = e.urgenza {
                componenti.append(["code": code(.urgenza), "valueInteger": u])
            }
            if !componenti.isEmpty { risorsa["component"] = componenti }
            voci.append(["resource": risorsa])
        }

        for g in i.giorni.sorted(by: { $0.giorno < $1.giorno }) {
            if let d = g.dolore {
                voci.append(["resource": [
                    "resourceType": "Observation",
                    "status": "final",
                    "code": code(.dolorePeggiore24h),
                    "effectiveDateTime": giornoISO(g.giorno),
                    "valueQuantity": ["value": d, "system": "http://unitsofmeasure.org", "code": "{score}"],
                ] as [String: Any]])
            }
        }

        let bundle: [String: Any] = [
            "resourceType": "Bundle",
            "type": "collection",
            "entry": voci,
        ]
        return try JSONSerialization.data(withJSONObject: bundle,
                                          options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
