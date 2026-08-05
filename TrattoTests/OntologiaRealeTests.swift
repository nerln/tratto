import Testing
import Foundation
@testable import Tratto

/// Prove sull'ontologia vera, quella spedita dentro l'app, non su un
/// sottoinsieme costruito ad arte.
///
/// Con 142 voci le collisioni sono reali: «pasta» sta dentro «pasta integrale»,
/// «pane di semola» e «pane integrale» condividono metà nome, «riso» compare
/// dentro «riso soffiato». È qui che un riconoscitore sbaglia, non su tre voci.
@Suite("Ontologia reale")
struct OntologiaRealeTests {

    private static let seed: SeedOntologia? = {
        // il bundle di prova è ospitato dall'app, quindi le risorse sono lì
        SeedOntologia.daBundle(Bundle(for: Ancora.self)) ?? SeedOntologia.daBundle(.main)
    }()

    private final class Ancora {}

    private func motore(_ seed: SeedOntologia) -> Corrispondenza {
        let voci = seed.ingredienti
            .map { Corrispondenza.Voce(identificativo: $0.id, nome: $0.nome,
                                       forme: [$0.nome, $0.id] + $0.sinonimi + $0.terminiLegacy2020) }
            .sorted { ($0.forme.map(\.count).max() ?? 0) > ($1.forme.map(\.count).max() ?? 0) }
        return Corrispondenza(voci: voci)
    }

    @Test("il seed spedito con l'app si carica e ha la forma attesa")
    func caricamento() throws {
        let seed = try #require(Self.seed, "seed-ontologia.json non trovato nel bundle")
        #expect(seed.ingredienti.count > 120)
        #expect(seed.ingredienti.allSatisfy { !$0.id.isEmpty && !$0.nome.isEmpty && !$0.categoria.isEmpty })
        // gli identificativi devono essere unici, altrimenti l'indice perde voci
        #expect(Set(seed.ingredienti.map(\.id)).count == seed.ingredienti.count)
    }

    @Test("nessun termine del 2020 è rivendicato da due voci diverse")
    func nessunTermineDoppio() throws {
        let seed = try #require(Self.seed)
        var proprietario: [String: String] = [:]
        var conflitti: [String] = []
        for v in seed.ingredienti {
            for t in v.terminiLegacy2020 {
                if let altro = proprietario[t], altro != v.id { conflitti.append("\(t): \(altro) / \(v.id)") }
                proprietario[t] = v.id
            }
        }
        #expect(conflitti.isEmpty, "termini contesi: \(conflitti)")
    }

    @Test("le due anagrafiche separate del 2020 confluiscono in una voce sola")
    func anagraficheUnificate() throws {
        let seed = try #require(Self.seed)
        // queste comparivano sia fra gli «alimenti» sia fra i «condimenti»
        for termine in ["carota", "tonno", "parmigiano", "finocchio", "salsiccia",
                        "insalata", "peperoni", "latte_senza_lattosio"] {
            let voci = seed.ingredienti.filter { $0.terminiLegacy2020.contains(termine) }
            #expect(voci.count == 1, "«\(termine)» finisce in \(voci.count) voci invece che in una")
        }
    }

    @Test("le quattro forme di pollo del 2020 diventano una voce con 26 esposizioni")
    func polloUnificato() throws {
        let seed = try #require(Self.seed)
        let pollo = try #require(seed.ingredienti.first { $0.id == "pollo" })
        #expect(Set(pollo.terminiLegacy2020) ==
                ["fettina_pollo", "cosciotti_pollo", "pollo_allo_spiedo", "pollo_pezzetti"])
        #expect(pollo.esposizioni2020 == 26)
    }

    @Test("frasi vere vengono riconosciute sull'ontologia completa")
    func frasiVere() throws {
        let seed = try #require(Self.seed)
        let m = motore(seed)
        let casi: [(String, Set<String>)] = [
            ("riso in bianco con un filo d'olio", ["riso", "olio_di_oliva"]),
            ("pasta integrale al pomodoro con il parmigiano",
             ["pasta_integrale", "pomodoro", "parmigiano"]),
            ("una mela e due gallette di riso", ["mela", "galletta_di_riso"]),
            ("insalata di finocchi con olio e limone",
             ["insalata", "finocchio", "olio_di_oliva", "limone"]),
            ("latte senza lattosio e riso soffiato",
             ["latte_senza_lattosio", "riso_soffiato"]),
            ("salsiccia con le zucchine e la cipolla",
             ["salsiccia", "zucchina", "cipolla"]),
            ("pane di semola con il prosciutto crudo",
             ["pane_di_semola", "prosciutto_crudo"]),
        ]
        for (frase, attesi) in casi {
            let trovati = Set(m.analizza(frase).riconosciuti.map(\.identificativo))
            #expect(trovati.isSuperset(of: attesi),
                    "«\(frase)» → \(trovati.sorted()), mancano \(attesi.subtracting(trovati).sorted())")
        }
    }

    @Test("la voce più specifica vince anche quando ne contiene un'altra")
    func specificita() throws {
        let seed = try #require(Self.seed)
        let m = motore(seed)
        func soli(_ frase: String) -> Set<String> {
            Set(m.analizza(frase).riconosciuti.map(\.identificativo))
        }
        #expect(soli("pasta integrale").contains("pasta_integrale"))
        #expect(!soli("pasta integrale").contains("pasta_di_grano"))
        #expect(soli("riso soffiato").contains("riso_soffiato"))
        #expect(!soli("riso soffiato").contains("riso"))
        #expect(soli("pane integrale").contains("pane_integrale"))
    }

    @Test("un cibo che non c'è resta fuori invece di essere approssimato a forza")
    func nienteInvenzioni() throws {
        let seed = try #require(Self.seed)
        let m = motore(seed)
        for frase in ["ho bevuto una birra", "quinoa con avocado", "kebab"] {
            let trovati = m.analizza(frase).riconosciuti
            #expect(trovati.isEmpty, "«\(frase)» ha prodotto \(trovati.map(\.identificativo))")
        }
    }

    @Test("l'archivio del 2020 si carica e i suoi conteggi tornano")
    func archivio() throws {
        let a = try #require(Archivio2020.daBundle(Bundle(for: Ancora.self))
                             ?? Archivio2020.daBundle(.main))
        #expect(a.conteggi.eventi == 107)
        #expect(a.conteggi.pasti == 149)
        #expect(a.conteggi.alimenti == 83)
        #expect(a.conteggi.condimenti == 79)
        #expect(a.conteggi.portate == 129)
        #expect(a.conteggi.giorniDiCalendario == 68)
        #expect(a.eventi.count == a.conteggi.eventi)
        #expect(a.pasti.count == a.conteggi.pasti)
        // la vecchia scala resta 0-5 e non viene toccata
        let valori = a.eventi.compactMap(\.consistenza)
        #expect(valori.allSatisfy { $0 >= 0 && $0 <= 5 })
        #expect(valori.count == 102)
    }

    @Test("ogni termine del 2020 usato nell'archivio si risolve sull'ontologia")
    func archivioRisolveTutto() throws {
        let seed = try #require(Self.seed)
        let a = try #require(Archivio2020.daBundle(Bundle(for: Ancora.self))
                             ?? Archivio2020.daBundle(.main))
        var noti = Set<String>()
        for v in seed.ingredienti { noti.formUnion(v.terminiLegacy2020) }
        var orfani = Set<String>()
        for p in a.pasti {
            for t in p.termini where !noti.contains(t) { orfani.insert(t) }
            #expect(p.canonici.count <= p.termini.count)
        }
        #expect(orfani.isEmpty, "termini senza voce canonica: \(orfani.sorted())")
    }

    @Test("le etichette dei gruppi restano quelle poche di conoscenza comune")
    func gruppiSobri() throws {
        let seed = try #require(Self.seed)
        let gruppi = Set(seed.ingredienti.flatMap(\.gruppi))
        #expect(gruppi.isSubset(of: ["lattosio", "glutine", "caffeina", "alcol"]),
                "gruppi inattesi: \(gruppi)")
        // nessuna etichetta FODMAP: quei dati non sono utilizzabili legalmente
        #expect(!gruppi.contains { $0.lowercased().contains("fodmap") })
    }
}
