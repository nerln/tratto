import Testing
import Foundation
@testable import Tratto

/// Scrive i "fixture d'oro": il contratto numerico che qualunque altra
/// implementazione del nucleo deve riprodurre.
///
/// Serve perché l'app esiste in due lingue di programmazione. Quella Apple è in
/// Swift, quella per Android e Windows è in TypeScript, e le due calcolano gli
/// stessi p-value esatti. Due implementazioni della stessa statistica sono un
/// modo eccellente di divergere in silenzio: questo file è l'unica cosa che lo
/// impedisce. Swift lo produce, TypeScript lo deve riprodurre cifra per cifra.
///
/// Non è un test dell'implementazione Swift: quella ha i suoi, con oracoli
/// esterni. Questo fissa il comportamento perché l'altra sponda ci si possa
/// ancorare.
@Suite("Fixture d'oro")
struct FixtureOroTests {

    private static var radiceRepo: URL {
        // TrattoTests/FixtureOro.swift -> su di due
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static func giorno(_ n: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 1, day: n))!
    }

    /// Le serie su cui si confrontano le due implementazioni. Coprono i casi in
    /// cui è facile divergere: pareggi, ex aequo, segni misti, unanimità,
    /// e il caso degenere di tutte differenze nulle.
    private static let serie: [(nome: String, valori: [Double])] = [
        ("unanime", [1, 2, 3, 4, 5, 6]),
        ("unanimeNegativo", [-1, -2, -3, -4, -5, -6]),
        ("quasiUnanime", [1, 2, 3, -0.5, 4, 1.5]),
        ("conPareggi", [-4, -2, 0, 3, -5, -1, 1, -4, -4, -3, 2, -4]),
        ("molteExAequo", [3, 3, 3, -1, -1, 2, 2, 2, 4]),
        ("tuttiPareggi", [0, 0, 0, 0, 0, 0]),
        ("cinqueSole", [1, 2, 3, 4, 5]),
        ("dieci", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        ("conDueZeri", [1, 2, 0, 3, 0, 4]),
        ("decimali", [0.5, -0.25, 1.0, 0.75, -0.5, 1.25, 0.0, 2.0]),
    ]

    @Test("scrive fixtures/golden.json e lo rilegge")
    func scrivi() throws {
        var radice: [String: Any] = [
            "versione": 2,
            "prodottoDa": "Tratto (Swift)",
            "nota": "Contratto numerico condiviso fra l'implementazione Swift e quella TypeScript. Se questi numeri cambiano, una delle due ha un bug.",
        ]

        // --- test dei segni
        var segni: [[String: Any]] = []
        for s in Self.serie {
            guard let e = TestEsatti.testDeiSegni(differenze: s.valori) else { continue }
            segni.append([
                "nome": s.nome, "valori": s.valori,
                "positivi": e.positivi, "negativi": e.negativi, "pareggi": e.pareggi,
                "coppieUsate": e.coppieUsate,
                "pUnilaterale": e.pUnilaterale, "pBilaterale": e.pBilaterale,
                "pMinimoRaggiungibile": e.pMinimoRaggiungibile,
            ])
        }
        radice["testDeiSegni"] = segni

        // --- wilcoxon, con entrambe le convenzioni sui pareggi
        var wil: [[String: Any]] = []
        for s in Self.serie {
            for conv in TestEsatti.Pareggi.allCases {
                guard let e = TestEsatti.wilcoxon(differenze: s.valori, pareggi: conv) else { continue }
                var voce: [String: Any] = [
                    "nome": s.nome, "convenzione": conv.rawValue, "valori": s.valori,
                    "wPositivo": e.wPositivo, "wNegativo": e.wNegativo,
                    "coppieUsate": e.coppieUsate, "pareggi": e.pareggi,
                    "ranghiConExAequo": e.ranghiConExAequo,
                    "pUnilaterale": e.pUnilaterale, "pBilaterale": e.pBilaterale,
                    "pMinimoRaggiungibile": e.pMinimoRaggiungibile,
                ]
                if let hl = e.stimaHodgesLehmann { voce["hodgesLehmann"] = hl }
                if let i = e.intervallo {
                    voce["intervallo"] = ["basso": i.basso, "alto": i.alto, "confidenza": i.confidenza]
                }
                wil.append(voce)
            }
        }
        radice["wilcoxon"] = wil

        // --- ranghi medi
        radice["ranghiMedi"] = [
            ["in": [3.0, 1.0, 2.0], "out": TestEsatti.ranghiMedi([3, 1, 2])],
            ["in": [1.0, 1.0, 3.0], "out": TestEsatti.ranghiMedi([1, 1, 3])],
            ["in": [5.0, 5.0, 5.0, 5.0], "out": TestEsatti.ranghiMedi([5, 5, 5, 5])],
            ["in": [2.0, 1.0, 2.0, 3.0, 1.0], "out": TestEsatti.ranghiMedi([2, 1, 2, 3, 1])],
        ]

        // --- potenza
        var potenza: [[String: Any]] = []
        for blocchi in [4, 5, 6, 7, 8, 9, 10] {
            for p in [0.6, 0.7, 0.8, 0.9, 1.0] {
                for uni in [false, true] {
                    guard let v = TestEsatti.potenzaTestDeiSegni(
                        blocchi: blocchi, probabilitaConcordanza: p, unilaterale: uni) else { continue }
                    potenza.append(["blocchi": blocchi, "p": p, "unilaterale": uni, "potenza": v])
                }
            }
        }
        radice["potenza"] = potenza
        radice["blocchiMinimi"] = [
            ["unilaterale": false, "n": TestEsatti.blocchiMinimi(unilaterale: false)],
            ["unilaterale": true, "n": TestEsatti.blocchiMinimi(unilaterale: true)],
        ]

        // --- descrittive
        let campione: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
        radice["descrittive"] = [
            "campione": campione,
            "media": Statistica.media(campione) as Any,
            "mediana": Statistica.mediana(campione) as Any,
            "deviazioneStandard": Statistica.deviazioneStandard(campione) as Any,
            "percentile25": Statistica.percentile(campione, 0.25) as Any,
            "percentile75": Statistica.percentile(campione, 0.75) as Any,
            "entropiaPiatta": Statistica.entropiaNormalizzata([2, 2, 2, 2]) as Any,
            "entropiaUniforme": Statistica.entropiaNormalizzata([1, 2, 3, 4]) as Any,
            "entropiaSchiacciata": Statistica.entropiaNormalizzata([2, 2, 2, 2, 2, 2, 2, 2, 3, 1]) as Any,
        ]

        // --- scomposizione della varianza
        var varianza: [[String: Any]] = []
        for (nome, gruppi) in [
            ("tuttaFraGiorni", [[1.0, 1.0], [5.0, 5.0], [9.0, 9.0]]),
            ("nienteFraGiorni", [[1.0, 9.0], [1.0, 9.0], [1.0, 9.0]]),
            ("sbilanciati", [[2.0], [3.0, 4.0, 5.0], [1.0, 2.0]]),
            ("realistico", [[3.0, 4.0], [2.0], [4.0, 4.0, 5.0], [3.0], [5.0, 6.0]]),
        ] {
            guard let c = Statistica.componentiVarianza(gruppi: gruppi) else { continue }
            varianza.append([
                "nome": nome, "gruppi": gruppi,
                "entroGiorno": c.entroGiorno, "fraGiorni": c.fraGiorni, "icc": c.icc,
                "osservazioni": c.osservazioni, "giorni": c.giorni,
                "mediaOsservazioniPerGiorno": c.mediaOsservazioniPerGiorno,
            ])
        }
        radice["componentiVarianza"] = varianza

        // --- autocorrelazione
        var acf: [[String: Any]] = []
        for (nome, valori) in [
            ("crescente", (1...20).map(Double.init)),
            ("alternata", (1...20).map { Double($0 % 2) }),
            ("costante", [Double](repeating: 4, count: 20)),
        ] {
            var serie: [Date: Double] = [:]
            for (i, v) in valori.enumerated() { serie[Self.giorno(i + 1)] = v }
            let r = Statistica.autocorrelazione(serie: serie, ritardiMassimi: 5, calendario: Self.cal)
            acf.append([
                "nome": nome, "valori": valori,
                "ritardi": r.map { ["ritardo": $0.ritardo, "r": $0.r as Any, "coppie": $0.coppie] },
            ])
        }
        radice["autocorrelazione"] = acf

        // --- differenza minima rilevabile
        var mde: [[String: Any]] = []
        for sd in [0.5, 1.0, 2.0, 2.4] {
            for periodi in [4, 6, 8, 10] {
                for gpp in [3, 5, 7] {
                    guard let s = Statistica.differenzaMinimaRilevabile(
                        sdGiornaliera: sd, periodi: periodi, giorniPerPeriodo: gpp) else { continue }
                    mde.append(["sd": sd, "periodi": periodi, "giorniPerPeriodo": gpp,
                                "giorniTotali": s.giorniTotali, "differenzaMinima": s.differenzaMinima])
                }
            }
        }
        radice["differenzaMinimaRilevabile"] = mde

        // --- quantile normale
        radice["quantileNormale"] = [0.001, 0.025, 0.5, 0.8, 0.9, 0.975, 0.999]
            .map { ["p": $0, "z": Statistica.quantileNormale($0)] }

        // --- sequenza dei blocchi
        var sequenze: [[String: Any]] = []
        for seme in [UInt64(1), 42, 999, 0xDEAD_BEEF] {
            sequenze.append([
                "seme": String(seme),
                "coppie": 6,
                "sequenza": MotoreSfida.sequenza(coppie: 6, seme: seme).map(\.rawValue),
            ])
        }
        radice["sequenzaBlocchi"] = sequenze

        // --- fattibilità
        var fatt: [[String: Any]] = []
        for coppie in [3, 5, 6, 8, 9, 10] {
            for uni in [false, true] {
                let f = MotoreSfida.fattibilita(coppie: coppie, giorniPerBlocco: 5,
                                                giorniDiPausa: 4, unilaterale: uni)
                fatt.append([
                    "coppie": coppie, "unilaterale": uni,
                    "giorniTotali": f.giorniTotali,
                    "pMinimoRaggiungibile": f.pMinimoRaggiungibile,
                    "concordanzeNecessarie": f.concordanzeNecessarie,
                    "potenza70": f.potenza70, "potenza80": f.potenza80, "potenza90": f.potenza90,
                    "raggiungibile": f.raggiungibile,
                    "coppiePerTollerareUnaDiscordanza": f.coppiePerTollerareUnaDiscordanza,
                ])
            }
        }
        radice["fattibilita"] = fatt

        // --- riconoscimento degli ingredienti sull'ontologia vera
        if let seed = SeedOntologia.daBundle(Bundle(for: Ancora.self))
            ?? SeedOntologia.daBundle(.main) {
            let voci = seed.ingredienti
                .map { Corrispondenza.Voce(identificativo: $0.id, nome: $0.nomeEn,
                                           forme: [$0.nomeIt, $0.nomeEn, $0.id]
                                                  + $0.sinonimi + $0.terminiLegacy2020) }
                .sorted { ($0.forme.map(\.count).max() ?? 0) > ($1.forme.map(\.count).max() ?? 0) }
            let m = Corrispondenza(voci: voci)
            let frasi = [
                "rice with a drizzle of olive oil",
                "wholewheat pasta with tomato and parmesan",
                "an apple and two rice cakes",
                "sausage with courgette and onion",
                "riso in bianco con un filo d'olio",
                "insalata di finocchi con olio e limone",
                "latte senza lattosio e riso soffiato",
                "pane di semola con il prosciutto crudo",
                "parmiggiano",
                "ho bevuto una birra",
                "quinoa con avocado",
                "oggi non ho avuto fame",
            ]
            radice["riconoscimento"] = frasi.map { f in
                let e = m.analizza(f)
                return [
                    "frase": f,
                    "riconosciuti": e.riconosciuti.map { ["id": $0.identificativo, "tipo": $0.tipo.rawValue] },
                    "nonRiconosciuti": e.nonRiconosciuti,
                ]
            }
        }

        // --- normalizzazione e distanza
        radice["normalizzazione"] = ["Olio d'oliva!", "  Caffè   ", "Pasta INTEGRALE", "", "a-b_c"]
            .map { ["in": $0, "out": Corrispondenza.normalizza($0)] }
        radice["distanza"] = [
            ["a": "riso", "b": "riso", "limite": 2, "out": Corrispondenza.distanza("riso", "riso", limite: 2)],
            ["a": "riso", "b": "viso", "limite": 2, "out": Corrispondenza.distanza("riso", "viso", limite: 2)],
            ["a": "parmigiano", "b": "parmiggiano", "limite": 2,
             "out": Corrispondenza.distanza("parmigiano", "parmiggiano", limite: 2)],
            ["a": "riso", "b": "elefante", "limite": 2, "out": Corrispondenza.distanza("riso", "elefante", limite: 2)],
        ]

        // --- copertura
        var fasce: [Date: Set<Fascia>] = [:]
        fasce[Self.giorno(1)] = [.colazione, .pranzo, .cena]
        fasce[Self.giorno(2)] = [.colazione]
        fasce[Self.giorno(4)] = [.colazione, .pranzo, .cena, .merenda]
        let giornate = Copertura.giornate(fasceRisolte: fasce,
                                          eventiPerGiorno: [Self.giorno(1): 2, Self.giorno(3): 1],
                                          giorniConEsito: [Self.giorno(1), Self.giorno(4)],
                                          calendario: Self.cal)
        radice["copertura"] = [
            "giornate": giornate.map { [
                "giorno": Esportazione.giornoISO($0.giorno),
                "fasceAttese": $0.fasceAttese, "fasceRisolte": $0.fasceRisolte,
                "eventi": $0.eventi, "haEsito": $0.haEsito,
                "frazione": $0.frazione, "completa": $0.completa,
            ] },
            "finestra7": {
                let f = Copertura.finestra(giornate, ultimi: 7, fine: Self.giorno(4), calendario: Self.cal)
                return ["giorni": f.giorni, "giorniCompleti": f.giorniCompleti,
                        "frazioneMedia": f.frazioneMedia, "giorniConEsito": f.giorniConEsito,
                        "giorniConEventi": f.giorniConEventi, "analizzabile": f.analizzabile]
            }(),
        ]

        // --- scala della forma
        radice["formaFecale"] = FormaFecale.allCases.map {
            ["valore": $0.rawValue, "chiaveEtichetta": $0.chiaveEtichetta,
             "chiaveDescrizione": $0.chiaveDescrizione,
             "zona": $0.zona.rawValue, "anormale": $0.anormale]
        }

        // --- codifiche
        radice["concetti"] = Concetto.allCases.map { c in
            [
                "id": c.rawValue,
                "etichettaInglese": c.etichetta(Locale(identifier: "en")),
                "codificaLocale": ["sistema": c.codificaLocale.sistema, "codice": c.codificaLocale.codice],
                "codificheEsterne": c.codificheEsterne.map {
                    ["sistema": $0.sistema, "codice": $0.codice, "etichetta": $0.etichetta] },
            ]
        }

        let dati = try JSONSerialization.data(
            withJSONObject: radice, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let cartella = Self.radiceRepo.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        let url = cartella.appendingPathComponent("golden.json")
        try dati.write(to: url)
        print("[tratto] fixture d'oro: \(url.path) (\(dati.count) byte)")

        // rileggibile e non vuoto
        let riletto = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect((riletto["wilcoxon"] as? [[String: Any]])?.count ?? 0 >= 15)
        #expect((riletto["potenza"] as? [[String: Any]])?.count ?? 0 >= 50)
        #expect((riletto["riconoscimento"] as? [[String: Any]])?.count == 12)
    }

    private final class Ancora {}
}
