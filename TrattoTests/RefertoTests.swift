import Testing
import Foundation
@testable import Tratto

/// Verifica che i file da consegnare vengano prodotti davvero e siano validi.
///
/// Se la variabile d'ambiente `TRATTO_ESPORTA_IN` è impostata, i file vengono
/// anche scritti lì: serve a guardarli con gli occhi, non solo ad asserirli.
@Suite("Referto e file di consegna")
struct RefertoTests {

    private static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    /// Una serie verosimile: 45 giorni, copertura non perfetta, forme
    /// concentrate al centro con code, dolore che oscilla.
    private func istantanea(giorni: Int = 45) -> Esportazione.Istantanea {
        let cal = Self.cal
        let oggi = cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: 8, day: 4))!)
        var seme: UInt64 = 0xC0FFEE_1234_5678
        func prossimo() -> UInt64 { seme ^= seme << 13; seme ^= seme >> 7; seme ^= seme << 17; return seme }
        func intero(_ r: ClosedRange<Int>) -> Int {
            r.lowerBound + Int(prossimo() % UInt64(r.count))
        }

        var eventi: [Esportazione.Istantanea.Evento] = []
        var pasti: [Esportazione.Istantanea.VocePasto] = []
        var giorniDati: [Esportazione.Istantanea.Giorno] = []
        var eventiRiep: [(quando: Date, forma: Int, dolore: Int?)] = []
        var pastiRiep: [(quando: Date, fascia: Fascia, risolto: Bool)] = []
        var vociRiep: [(quando: Date, ingrediente: String, nome: String, categoria: String)] = []
        var esitiRiep: [(giorno: Date, dolore: Int?)] = []

        for indietro in stride(from: giorni - 1, through: 0, by: -1) {
            let g = cal.date(byAdding: .day, value: -indietro, to: oggi)!
            for fascia in Fascia.attese {
                let quando = cal.date(bySettingHour: fascia.oraTipica, minute: 0, second: 0, of: g)!
                let salta = intero(1...100) > 82
                pastiRiep.append((quando, fascia, !salta))
                if salta {
                    pasti.append(.init(quando: quando, fascia: fascia.chiaveNome, stato: "digiuno",
                                       ingredienteId: "", ingredienteNome: "", categoria: "",
                                       quantita: "", testoGrezzo: ""))
                } else {
                    for (id, nome, cat) in [("riso", "Riso", "Cereali"), ("olio_di_oliva", "Olio d'oliva", "Grassi")] {
                        pasti.append(.init(quando: quando, fascia: fascia.chiaveNome, stato: "registrato",
                                           ingredienteId: id, ingredienteNome: nome, categoria: cat,
                                           quantita: "normale", testoGrezzo: "riso e olio"))
                        vociRiep.append((quando, id, nome, cat))
                    }
                }
            }
            for _ in 0..<intero(1...3) {
                let quando = cal.date(bySettingHour: intero(6...21), minute: intero(0...59), second: 0, of: g)!
                let sorte = intero(1...100)
                let forma = switch sorte {
                case 1...9: 2
                case 10...30: 3
                case 31...64: 4
                case 65...85: 5
                case 86...96: 6
                default: 7
                }
                eventi.append(.init(quando: quando, forma: forma, urgenza: intero(0...7),
                                    dolore: nil, sangue: false, note: ""))
                eventiRiep.append((quando, forma, nil))
            }
            let dolore = intero(0...7)
            giorniDati.append(.init(giorno: g, dolore: dolore, gonfiore: intero(0...5),
                                    oreSonno: Double(intero(11...17)) / 2, stress: intero(0...8),
                                    caffe: intero(0...3), alcol: false, esercizio: true, atipica: false))
            esitiRiep.append((g, dolore))
        }

        let riepilogo = Riepilogo.costruisci(da: .init(
            eventi: eventiRiep, pasti: pastiRiep, vociPasto: vociRiep,
            esiti: esitiRiep, calendario: cal))

        return .init(eventi: eventi, pasti: pasti, giorni: giorniDati,
                     riepilogo: riepilogo, codificheEsterne: true)
    }

    /// I file prodotti vengono lasciati su disco: un referto destinato a un
    /// medico va guardato, non solo asserito.
    private static var cartellaVerifica: URL {
        let percorso = ProcessInfo.processInfo.environment["TRATTO_ESPORTA_IN"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("tratto-verifica").path
        return URL(fileURLWithPath: percorso)
    }

    private func salva(_ nome: String, _ dati: Data) {
        let cartella = Self.cartellaVerifica
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        let url = cartella.appendingPathComponent(nome)
        try? dati.write(to: url)
        print("[tratto] scritto \(url.path) (\(dati.count) byte)")
    }

    @MainActor
    @Test("il referto PDF viene prodotto ed è un PDF valido")
    func referto() throws {
        let dati = istantanea()
        let pdf = try #require(Referto.pdf(dati), "il renderizzatore non ha prodotto niente")
        #expect(pdf.count > 5_000, "un PDF di \(pdf.count) byte è sospettosamente vuoto")
        #expect(pdf.prefix(5) == Data("%PDF-".utf8))
        #expect(pdf.suffix(1024).range(of: Data("%%EOF".utf8)) != nil)
        salva("tratto-referto.pdf", pdf)
    }

    @Test("i tre CSV hanno intestazione e almeno una riga per giorno")
    func csv() throws {
        let dati = istantanea()
        let eventi = Esportazione.csvEventi(dati)
        let pastiCsv = Esportazione.csvPasti(dati)
        let giorni = Esportazione.csvGiorni(dati)

        #expect(eventi.hasPrefix("quando,forma_1_7"))
        #expect(eventi.split(separator: "\n").count == dati.eventi.count + 1)
        #expect(pastiCsv.split(separator: "\n").count == dati.pasti.count + 1)
        #expect(giorni.split(separator: "\n").count == dati.giorni.count + 1)
        // la copertura finisce nel file giornaliero
        #expect(giorni.contains(",3,"))

        salva("tratto-eventi.csv", Data(eventi.utf8))
        salva("tratto-pasti.csv", Data(pastiCsv.utf8))
        salva("tratto-giorni.csv", Data(giorni.utf8))
    }

    @Test("il bundle FHIR contiene una osservazione per evento e una per giornata con dolore")
    func fhir() throws {
        let dati = istantanea()
        let json = try Esportazione.fhir(dati)
        let radice = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(radice["resourceType"] as? String == "Bundle")
        let voci = try #require(radice["entry"] as? [[String: Any]])
        let attese = dati.eventi.count + dati.giorni.filter { $0.dolore != nil }.count
        #expect(voci.count == attese)
        salva("tratto-fhir.json", json)
    }

    @Test("il JSON completo si rilegge e contiene tutti i giorni")
    func json() throws {
        let dati = istantanea()
        let json = try Esportazione.json(dati)
        let radice = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect((radice["giorni"] as? [[String: Any]])?.count == dati.giorni.count)
        #expect((radice["eventi"] as? [[String: Any]])?.count == dati.eventi.count)
        salva("tratto-dati.json", json)
    }

    @Test("il referto non contiene mai un accostamento fra un alimento e un esito")
    func nessunaAssociazione() throws {
        // La garanzia è strutturale: nel riepilogo non esiste alcun campo che
        // leghi un ingrediente a un esito. Questo test la fissa, così una
        // aggiunta futura la fa fallire invece di passare inosservata.
        let r = istantanea().riepilogo
        #expect(!r.esposizioni.isEmpty)
        let campi = Mirror(reflecting: r.esposizioni[0]).children.compactMap(\.label)
        #expect(campi.sorted() == ["categoria", "esposizioni", "giorniDistinti",
                                   "identificativo", "nome", "ultimaVolta"])
    }
}
