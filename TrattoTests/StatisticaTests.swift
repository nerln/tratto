import Testing
import Foundation
@testable import Tratto

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Rome")!
    return c
}()

private func giorno(_ g: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 1, day: g))!
}

private func istante(_ g: Int, _ ora: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 1, day: g, hour: ora))!
}

@Suite("Descrittive")
struct DescrittiveTests {

    @Test("media e mediana")
    func medieBase() {
        #expect(Statistica.media([1, 2, 3, 4]) == 2.5)
        #expect(Statistica.mediana([1, 2, 3, 4]) == 2.5)
        #expect(Statistica.mediana([3, 1, 2]) == 2)
        #expect(Statistica.media([]) == nil)
    }

    @Test("deviazione standard campionaria, non di popolazione")
    func deviazione() throws {
        // per [2,4,4,4,5,5,7,9] la DS di popolazione e' 2, quella campionaria ~2.138
        let sd = try #require(Statistica.deviazioneStandard([2, 4, 4, 4, 5, 5, 7, 9]))
        #expect(abs(sd - 2.13809) < 0.0001)
        #expect(Statistica.deviazioneStandard([5]) == nil)
    }

    @Test("una serie costante ha deviazione zero")
    func costante() {
        #expect(Statistica.deviazioneStandard([3, 3, 3, 3]) == 0)
    }

    @Test("l'entropia distingue una variabile piatta da una che usa la scala")
    func entropia() throws {
        #expect(Statistica.entropiaNormalizzata([2, 2, 2, 2]) == 0)
        let uniforme = try #require(Statistica.entropiaNormalizzata([1, 2, 3, 4]))
        #expect(abs(uniforme - 1) < 1e-9)
        // schiacciata su due livelli vicini: molto piu' bassa
        let schiacciata = try #require(
            Statistica.entropiaNormalizzata([2, 2, 2, 2, 2, 2, 2, 2, 3, 1]))
        #expect(schiacciata < 0.7)
    }

    @Test("percentile interpola")
    func percentili() throws {
        let x: [Double] = [1, 2, 3, 4, 5]
        #expect(Statistica.percentile(x, 0) == 1)
        #expect(Statistica.percentile(x, 1) == 5)
        #expect(Statistica.percentile(x, 0.5) == 3)
        let q = try #require(Statistica.percentile(x, 0.25))
        #expect(abs(q - 2) < 1e-9)
    }
}

@Suite("Scomposizione della varianza")
struct VarianzaTests {

    @Test("se i gruppi sono identici al loro interno, tutta la varianza sta fra i gruppi")
    func iccMassimo() throws {
        let c = try #require(Statistica.componentiVarianza(gruppi: [[1, 1], [5, 5], [9, 9]]))
        #expect(c.entroGiorno == 0)
        #expect(abs(c.icc - 1) < 1e-9)
        #expect(c.giorni == 3)
        #expect(c.osservazioni == 6)
    }

    @Test("se i gruppi hanno la stessa media, la quota fra gruppi crolla a zero")
    func iccMinimo() throws {
        let c = try #require(Statistica.componentiVarianza(gruppi: [[1, 9], [1, 9], [1, 9]]))
        #expect(c.icc == 0)
        #expect(c.entroGiorno > 0)
    }

    @Test("gruppi di dimensione diversa non fanno esplodere il calcolo")
    func sbilanciati() throws {
        let c = try #require(Statistica.componentiVarianza(gruppi: [[2], [3, 4, 5], [1, 2]]))
        #expect(c.icc >= 0 && c.icc <= 1)
        #expect(c.osservazioni == 6)
        #expect(abs(c.mediaOsservazioniPerGiorno - 2) < 1e-9)
    }

    @Test("serve piu' di un gruppo")
    func troppoPochi() {
        #expect(Statistica.componentiVarianza(gruppi: [[1, 2, 3]]) == nil)
        #expect(Statistica.componentiVarianza(gruppi: []) == nil)
    }
}

@Suite("Autocorrelazione")
struct AutocorrelazioneTests {

    @Test("una serie che sale sempre e' fortemente autocorrelata a distanza 1")
    func crescente() throws {
        var serie: [Date: Double] = [:]
        for i in 1...20 { serie[giorno(i)] = Double(i) }
        let acf = Statistica.autocorrelazione(serie: serie, ritardiMassimi: 3, calendario: cal)
        let primo = try #require(acf.first(where: { $0.ritardo == 1 })?.r)
        #expect(abs(primo - 1) < 1e-9)
        #expect(acf.first(where: { $0.ritardo == 1 })?.coppie == 19)
    }

    @Test("una serie che alterna e' anticorrelata a distanza 1 e correlata a distanza 2")
    func alternata() throws {
        var serie: [Date: Double] = [:]
        for i in 1...20 { serie[giorno(i)] = i % 2 == 0 ? 1 : 0 }
        let acf = Statistica.autocorrelazione(serie: serie, ritardiMassimi: 2, calendario: cal)
        let r1 = try #require(acf.first(where: { $0.ritardo == 1 })?.r)
        let r2 = try #require(acf.first(where: { $0.ritardo == 2 })?.r)
        #expect(r1 < -0.9)
        #expect(r2 > 0.9)
    }

    @Test("i giorni mancanti vengono saltati invece che inventati")
    func buchi() {
        var serie: [Date: Double] = [:]
        for i in [1, 2, 3, 7, 8, 9, 13, 14, 15] { serie[giorno(i)] = Double(i) }
        let acf = Statistica.autocorrelazione(serie: serie, ritardiMassimi: 1,
                                              coppieMinime: 3, calendario: cal)
        // solo le coppie realmente contigue: (1,2),(2,3),(7,8),(8,9),(13,14),(14,15)
        #expect(acf.first?.coppie == 6)
    }

    @Test("con troppe poche coppie non restituisce un numero")
    func poche() {
        var serie: [Date: Double] = [:]
        for i in 1...4 { serie[giorno(i)] = Double(i) }
        let acf = Statistica.autocorrelazione(serie: serie, ritardiMassimi: 1,
                                              coppieMinime: 8, calendario: cal)
        #expect(acf.first?.r == nil)
    }

    @Test("la pausa suggerita e' il primo ritardo che scende sotto la soglia")
    func pausa() {
        let acf = [
            Statistica.Autocorrelazione(ritardo: 1, r: 0.62, coppie: 40),
            Statistica.Autocorrelazione(ritardo: 2, r: 0.31, coppie: 39),
            Statistica.Autocorrelazione(ritardo: 3, r: 0.11, coppie: 38),
        ]
        #expect(Statistica.pausaSuggerita(acf, soglia: 0.2) == 3)
        #expect(Statistica.pausaSuggerita(acf, soglia: 0.05) == nil)
    }
}

@Suite("Differenza minima rilevabile")
struct RilevabilitaTests {

    @Test("piu' confronti e piu' giorni per confronto rendono rilevabili effetti piu' piccoli")
    func monotona() throws {
        let pochi = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 1.0, periodi: 4, giorniPerPeriodo: 3))
        let piuPeriodi = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 1.0, periodi: 8, giorniPerPeriodo: 3))
        let piuGiorni = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 1.0, periodi: 4, giorniPerPeriodo: 7))
        #expect(piuPeriodi.differenzaMinima < pochi.differenzaMinima)
        #expect(piuGiorni.differenzaMinima < pochi.differenzaMinima)
    }

    @Test("piu' rumore alza la soglia in modo proporzionale")
    func proporzionale() throws {
        let a = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 1.0, periodi: 6, giorniPerPeriodo: 5))
        let b = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 2.0, periodi: 6, giorniPerPeriodo: 5))
        #expect(abs(b.differenzaMinima - 2 * a.differenzaMinima) < 1e-9)
    }

    @Test("i giorni totali contano entrambe le condizioni")
    func giorniTotali() throws {
        let s = try #require(Statistica.differenzaMinimaRilevabile(
            sdGiornaliera: 1.0, periodi: 6, giorniPerPeriodo: 5))
        #expect(s.giorniTotali == 60)
    }

    @Test("dati insensati non producono un numero")
    func limiti() {
        #expect(Statistica.differenzaMinimaRilevabile(sdGiornaliera: 0, periodi: 6, giorniPerPeriodo: 3) == nil)
        #expect(Statistica.differenzaMinimaRilevabile(sdGiornaliera: 1, periodi: 1, giorniPerPeriodo: 3) == nil)
    }

    @Test("il quantile normale e' quello atteso ai valori noti")
    func quantile() {
        #expect(abs(Statistica.quantileNormale(0.975) - 1.959964) < 1e-4)
        #expect(abs(Statistica.quantileNormale(0.80) - 0.841621) < 1e-4)
        #expect(abs(Statistica.quantileNormale(0.5)) < 1e-9)
    }
}

@Suite("Copertura")
struct CoperturaTests {

    @Test("una fascia risolta con «niente» conta quanto una con del cibo")
    func digiunoConta() {
        let g = Copertura.giornate(
            fasceRisolte: [giorno(1): [.colazione, .pranzo, .cena]],
            eventiPerGiorno: [:], giorniConEsito: [], calendario: cal)
        #expect(g.count == 1)
        #expect(g[0].completa)
        #expect(g[0].frazione == 1)
    }

    @Test("i giorni vuoti dentro l'intervallo compaiono lo stesso, a copertura zero")
    func giorniVuoti() {
        let g = Copertura.giornate(
            fasceRisolte: [giorno(1): [.colazione], giorno(5): [.cena]],
            eventiPerGiorno: [:], giorniConEsito: [], calendario: cal)
        #expect(g.count == 5)
        #expect(g[1].frazione == 0)
        #expect(g[1].eventi == 0)
        #expect(!g[1].completa)
    }

    @Test("gli spuntini non entrano nel conto delle fasce attese")
    func spuntiniEsclusi() {
        let g = Copertura.giornate(
            fasceRisolte: [giorno(1): [.colazione, .pranzo, .cena, .merenda]],
            eventiPerGiorno: [:], giorniConEsito: [], calendario: cal)
        #expect(g[0].fasceAttese == 3)
        #expect(g[0].fasceRisolte == 3)
    }

    @Test("la finestra divide per i giorni richiesti, non per quelli registrati")
    func finestraSuGiorniRichiesti() {
        // un solo giorno pieno su sette: la copertura media deve essere ~1/7, non 1
        let giornate = Copertura.giornate(
            fasceRisolte: [giorno(10): [.colazione, .pranzo, .cena]],
            eventiPerGiorno: [:], giorniConEsito: [], calendario: cal)
        let f = Copertura.finestra(giornate, ultimi: 7, fine: giorno(10), calendario: cal)
        #expect(abs(f.frazioneMedia - 1.0 / 7.0) < 1e-9)
        #expect(!f.analizzabile)
        #expect(f.giorniCompleti == 1)
    }

    @Test("sette giorni pieni sono analizzabili")
    func settePieni() {
        var fasce: [Date: Set<Fascia>] = [:]
        for i in 4...10 { fasce[giorno(i)] = [.colazione, .pranzo, .cena] }
        let giornate = Copertura.giornate(fasceRisolte: fasce, eventiPerGiorno: [:],
                                          giorniConEsito: [], calendario: cal)
        let f = Copertura.finestra(giornate, ultimi: 7, fine: giorno(10), calendario: cal)
        #expect(abs(f.frazioneMedia - 1) < 1e-9)
        #expect(f.analizzabile)
    }
}

@Suite("Riepilogo")
struct RiepilogoTests {

    private func ingresso(giorni: Int, dolore: (Int) -> Int?) -> Riepilogo.Ingresso {
        var eventi: [(quando: Date, forma: Int, dolore: Int?)] = []
        var pasti: [(quando: Date, fascia: Fascia, risolto: Bool)] = []
        var voci: [(quando: Date, ingrediente: String, nome: String, categoria: String)] = []
        var esiti: [(giorno: Date, dolore: Int?)] = []
        for i in 1...giorni {
            eventi.append((istante(i, 9), 3 + (i % 3), nil))
            for f in Fascia.attese {
                pasti.append((istante(i, f.oraTipica), f, true))
            }
            voci.append((istante(i, 13), "riso", "Riso", "Cereali"))
            if i % 2 == 0 { voci.append((istante(i, 13), "mela", "Mela", "Frutta")) }
            esiti.append((giorno(i), dolore(i)))
        }
        return .init(eventi: eventi, pasti: pasti, vociPasto: voci, esiti: esiti, calendario: cal)
    }

    @Test("conta le esposizioni e i giorni distinti, e le ordina per frequenza")
    func esposizioni() throws {
        let r = Riepilogo.costruisci(da: ingresso(giorni: 10, dolore: { _ in 4 }))
        let riso = try #require(r.esposizioni.first { $0.identificativo == "riso" })
        let mela = try #require(r.esposizioni.first { $0.identificativo == "mela" })
        #expect(riso.esposizioni == 10)
        #expect(riso.giorniDistinti == 10)
        #expect(mela.esposizioni == 5)
        #expect(r.esposizioni.first?.identificativo == "riso")
    }

    @Test("la stima di rilevabilita' non compare finche' la serie e' corta")
    func rilevabilitaSoloDopo() {
        let corta = Riepilogo.costruisci(da: ingresso(giorni: 10, dolore: { i in i % 5 }))
        #expect(corta.rilevabilita.isEmpty)

        let lunga = Riepilogo.costruisci(da: ingresso(giorni: 30, dolore: { i in i % 5 }))
        #expect(!lunga.rilevabilita.isEmpty)
    }

    @Test("con un dolore sempre uguale non si stima nessuna rilevabilita': non c'e' rumore da misurare")
    func doloreCostante() {
        let r = Riepilogo.costruisci(da: ingresso(giorni: 30, dolore: { _ in 4 }))
        #expect(r.dolore.deviazioneStandard == 0)
        #expect(r.rilevabilita.isEmpty)
    }

    @Test("i giorni completi vengono contati")
    func completi() {
        let r = Riepilogo.costruisci(da: ingresso(giorni: 12, dolore: { _ in 3 }))
        #expect(r.giorniCompletiTotali == 12)
        #expect(r.eventiTotali == 12)
    }

    @Test("il riepilogo vuoto non esplode")
    func vuoto() {
        let r = Riepilogo.costruisci(da: .init(eventi: [], pasti: [], vociPasto: [],
                                               esiti: [], calendario: cal))
        #expect(r.periodo == nil)
        #expect(r.giornate.isEmpty)
        #expect(r.esposizioni.isEmpty)
        #expect(r.rilevabilita.isEmpty)
    }
}
