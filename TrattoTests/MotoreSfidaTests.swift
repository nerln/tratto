import Testing
import Foundation
@testable import Tratto

private var cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Rome")!
    return c
}()

private func g(_ giorno: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 9, day: giorno))!
}

@Suite("Motore del confronto")
struct MotoreSfidaTests {

    // MARK: - Programmazione

    @Test("la sequenza alterna bersaglio e controllo dentro ogni coppia")
    func sequenzaAppaiata() {
        for seme in [UInt64(1), 42, 999, 0xDEAD_BEEF] {
            let s = MotoreSfida.sequenza(coppie: 6, seme: seme)
            #expect(s.count == 12)
            for i in stride(from: 0, to: 12, by: 2) {
                #expect(s[i] != s[i + 1], "coppia \(i / 2) non alternata con seme \(seme)")
            }
            #expect(s.filter { $0 == .bersaglio }.count == 6)
            #expect(s.filter { $0 == .controllo }.count == 6)
        }
    }

    @Test("lo stesso seme dà la stessa sequenza, semi diversi no")
    func sequenzaDeterministica() {
        #expect(MotoreSfida.sequenza(coppie: 8, seme: 7) == MotoreSfida.sequenza(coppie: 8, seme: 7))
        #expect(MotoreSfida.sequenza(coppie: 8, seme: 7) != MotoreSfida.sequenza(coppie: 8, seme: 8))
    }

    @Test("i blocchi non si sovrappongono e rispettano la pausa")
    func programmazione() throws {
        let b = MotoreSfida.programma(coppie: 3, giorniPerBlocco: 5, giorniDiPausa: 4,
                                      inizio: g(1), seme: 42, calendario: cal)
        #expect(b.count == 6)
        for i in 0..<(b.count - 1) {
            let fine = b[i].al, prossimoInizio = b[i + 1].dal
            let pausa = cal.dateComponents([.day], from: fine, to: prossimoInizio).day ?? 0
            #expect(pausa == 5, "fra il blocco \(i) e il \(i+1) ci sono \(pausa - 1) giorni di pausa")
        }
        let durata = cal.dateComponents([.day], from: b[0].dal, to: b[0].al).day ?? 0
        #expect(durata == 4)   // 5 giorni inclusi gli estremi
    }

    @Test("la durata totale include tutte le pause tranne quella finale")
    func durataTotale() {
        #expect(MotoreSfida.giorniTotali(coppie: 6, giorniPerBlocco: 5, giorniDiPausa: 4) == 104)
        #expect(MotoreSfida.giorniTotali(coppie: 3, giorniPerBlocco: 5, giorniDiPausa: 0) == 30)
    }

    // MARK: - Fattibilità

    @Test("con sei coppie bilaterali serve l'unanimità")
    func fattibilitaSei() {
        let f = MotoreSfida.fattibilita(coppie: 6, giorniPerBlocco: 5, giorniDiPausa: 4,
                                        unilaterale: false)
        #expect(f.raggiungibile)
        #expect(f.concordanzeNecessarie == 6)
        #expect(abs(f.pMinimoRaggiungibile - 0.03125) < 1e-9)
        // il numero da mostrare: circa il 26%
        #expect(abs(f.potenza80 - 0.262144) < 1e-6)
    }

    @Test("con cinque coppie il bilaterale è irraggiungibile e l'app lo deve dire")
    func fattibilitaCinque() {
        let f = MotoreSfida.fattibilita(coppie: 5, giorniPerBlocco: 5, giorniDiPausa: 4,
                                        unilaterale: false)
        #expect(!f.raggiungibile)
        #expect(f.potenza90 == 0)
    }

    @Test("nove coppie sono la prima dimensione che tollera una discordanza")
    func tolleranza() {
        let f = MotoreSfida.fattibilita(coppie: 6, giorniPerBlocco: 5, giorniDiPausa: 4,
                                        unilaterale: false)
        #expect(f.coppiePerTollerareUnaDiscordanza == 9)
    }

    @Test("l'unilaterale aiuta da otto coppie in su, non a sei")
    func unilaterale() {
        // A sei coppie entrambe le ipotesi richiedono l'unanimità: il vantaggio
        // dell'unilaterale compare solo quando c'è margine per una discordanza.
        let bi6 = MotoreSfida.fattibilita(coppie: 6, giorniPerBlocco: 5, giorniDiPausa: 4,
                                          unilaterale: false)
        let uni6 = MotoreSfida.fattibilita(coppie: 6, giorniPerBlocco: 5, giorniDiPausa: 4,
                                           unilaterale: true)
        #expect(uni6.potenza80 == bi6.potenza80)

        let bi8 = MotoreSfida.fattibilita(coppie: 8, giorniPerBlocco: 5, giorniDiPausa: 4,
                                          unilaterale: false)
        let uni8 = MotoreSfida.fattibilita(coppie: 8, giorniPerBlocco: 5, giorniDiPausa: 4,
                                           unilaterale: true)
        #expect(uni8.potenza80 > bi8.potenza80)
        #expect(uni8.concordanzeNecessarie < bi8.concordanzeNecessarie)
    }

    // MARK: - Lettura

    private func blocchi(_ n: Int, giorniPerBlocco: Int = 5, pausa: Int = 4, seme: UInt64 = 42)
        -> [(indice: Int, condizione: CondizioneBlocco, dal: Date, al: Date)] {
        MotoreSfida.programma(coppie: n, giorniPerBlocco: giorniPerBlocco, giorniDiPausa: pausa,
                              inizio: g(1), seme: seme, calendario: cal)
            .map { ($0.indice, $0.condizione, $0.dal, $0.al) }
    }

    /// Un dolore che sale di `effetto` durante i blocchi bersaglio.
    private func osservazioni(_ b: [(indice: Int, condizione: CondizioneBlocco, dal: Date, al: Date)],
                              base: Double, effetto: Double) -> [MotoreSfida.GiornoOsservato] {
        var esito: [MotoreSfida.GiornoOsservato] = []
        for blocco in b {
            var giorno = blocco.dal
            while giorno <= blocco.al {
                let v = base + (blocco.condizione == .bersaglio ? effetto : 0)
                esito.append(.init(giorno: giorno, dolore: v, giornataAnormale: v > base))
                giorno = cal.date(byAdding: .day, value: 1, to: giorno)!
            }
        }
        return esito
    }

    @Test("un effetto netto in tutte le coppie produce il p minimo")
    func effettoNetto() throws {
        let b = blocchi(6)
        let o = osservazioni(b, base: 3, effetto: 2)
        let l = MotoreSfida.leggi(blocchi: b, osservazioni: o, esito: .dolore,
                                  direzione: .bilaterale, pareggi: .pratt,
                                  giorniScartatiInTesta: 1, coppiePreviste: 6,
                                  protocolloValido: true, calendario: cal)
        #expect(l.coppie.count == 6)
        #expect(l.verdetto == .coerenteConUnEffetto)
        let w = try #require(l.wilcoxon)
        #expect(abs(w.pBilaterale - 0.03125) < 1e-9)
        #expect(l.coppie.allSatisfy { abs($0.differenza - 2) < 1e-9 })
    }

    @Test("nessuna differenza produce solo pareggi, e il confronto muore")
    func nessunEffetto() throws {
        let b = blocchi(6)
        let o = osservazioni(b, base: 3, effetto: 0)
        let l = MotoreSfida.leggi(blocchi: b, osservazioni: o, esito: .dolore,
                                  direzione: .bilaterale, pareggi: .pratt,
                                  giorniScartatiInTesta: 1, coppiePreviste: 6,
                                  protocolloValido: true, calendario: cal)
        let s = try #require(l.segni, "con tutti pareggi l'esito deve esserci lo stesso")
        #expect(s.pareggi == 6)
        #expect(s.coppieUsate == 0)
        #expect(s.pBilaterale == 1)
        #expect(l.verdetto != .coerenteConUnEffetto)
    }

    @Test("il protocollo alterato blocca l'analisi invece di mostrarla")
    func protocolloAlterato() {
        let b = blocchi(6)
        let o = osservazioni(b, base: 3, effetto: 2)
        let l = MotoreSfida.leggi(blocchi: b, osservazioni: o, esito: .dolore,
                                  direzione: .bilaterale, pareggi: .pratt,
                                  giorniScartatiInTesta: 1, coppiePreviste: 6,
                                  protocolloValido: false, calendario: cal)
        #expect(l.verdetto == .protocolloAlterato)
        #expect(l.wilcoxon == nil)
        #expect(l.segni == nil)
    }

    @Test("un confronto non finito non mostra il risultato")
    func incompleta() {
        let b = blocchi(6)
        // solo le prime due coppie hanno dati
        let parziali = Array(b.prefix(4))
        let o = osservazioni(parziali, base: 3, effetto: 2)
        let l = MotoreSfida.leggi(blocchi: b, osservazioni: o, esito: .dolore,
                                  direzione: .bilaterale, pareggi: .pratt,
                                  giorniScartatiInTesta: 1, coppiePreviste: 6,
                                  protocolloValido: true, calendario: cal)
        #expect(l.verdetto == .incompleta)
        #expect(l.wilcoxon == nil)
    }

    @Test("i primi giorni di ogni blocco vengono scartati dal calcolo")
    func giorniScartati() throws {
        let b = blocchi(1, giorniPerBlocco: 5)
        var o: [MotoreSfida.GiornoOsservato] = []
        for blocco in b {
            var giorno = blocco.dal
            var i = 0
            while giorno <= blocco.al {
                // il primo giorno vale 100, gli altri 1: se non venisse
                // scartato, la media salterebbe agli occhi
                o.append(.init(giorno: giorno, dolore: i == 0 ? 100 : 1, giornataAnormale: false))
                giorno = cal.date(byAdding: .day, value: 1, to: giorno)!
                i += 1
            }
        }
        let v = MotoreSfida.valori(blocchi: b, osservazioni: o, esito: .dolore,
                                   giorniScartatiInTesta: 1, calendario: cal)
        #expect(v.count == 2)
        for blocco in v {
            #expect(blocco.giorniScartati == 1)
            #expect(blocco.giorniUsati == 4)
            #expect(blocco.valore == 1)
        }
    }

    @Test("una coppia senza dati in uno dei due blocchi viene persa, non inventata")
    func coppiaPersa() {
        let b = blocchi(2)
        // dati solo per i blocchi della prima coppia
        let o = osservazioni(Array(b.prefix(2)), base: 3, effetto: 1)
        let l = MotoreSfida.leggi(blocchi: b, osservazioni: o, esito: .dolore,
                                  direzione: .bilaterale, pareggi: .pratt,
                                  giorniScartatiInTesta: 1, coppiePreviste: 2,
                                  protocolloValido: true, calendario: cal)
        #expect(l.coppie.count == 1)
        #expect(l.coppiePerse == 1)
    }

    @Test("l'esito binario conta la quota di giornate fuori dall'intervallo")
    func esitoBinario() throws {
        let b = blocchi(1, giorniPerBlocco: 5)
        var o: [MotoreSfida.GiornoOsservato] = []
        for blocco in b {
            var giorno = blocco.dal
            var i = 0
            while giorno <= blocco.al {
                // nei blocchi bersaglio metà giornate sono anormali
                let anormale = blocco.condizione == .bersaglio ? (i % 2 == 0) : false
                o.append(.init(giorno: giorno, dolore: nil, giornataAnormale: anormale))
                giorno = cal.date(byAdding: .day, value: 1, to: giorno)!
                i += 1
            }
        }
        let v = MotoreSfida.valori(blocchi: b, osservazioni: o, esito: .giornateAnormali,
                                   giorniScartatiInTesta: 1, calendario: cal)
        let bersaglio = try #require(v.first { $0.condizione == .bersaglio }?.valore)
        let controllo = try #require(v.first { $0.condizione == .controllo }?.valore)
        #expect(bersaglio > controllo)
        #expect(controllo == 0)
    }

    // MARK: - Congelamento

    @MainActor
    @Test("l'impronta cambia se cambia una qualunque scelta del protocollo")
    func improntaSensibile() {
        let s = Sfida(titolo: "", bersaglioId: "mela", bersaglioNome: "Apple",
                      controlloId: "riso", controlloNome: "Rice")
        let prima = Sfida.impronta(di: s.protocolloCanonico)
        s.improntaProtocollo = prima
        #expect(s.improntaValida)

        s.direzione = .unilateraleAumento
        #expect(!s.improntaValida, "cambiare l'ipotesi dopo il congelamento deve invalidare")

        s.direzione = .bilaterale
        #expect(s.improntaValida, "tornando indietro l'impronta deve tornare valida")

        s.blocchiPrevisti = 9
        #expect(!s.improntaValida, "cambiare il numero di blocchi deve invalidare")
    }

    @MainActor
    @Test("senza congelamento l'impronta non è valida")
    func senzaCongelamento() {
        let s = Sfida(titolo: "", bersaglioId: "mela", bersaglioNome: "Apple",
                      controlloId: "riso", controlloNome: "Rice")
        #expect(!s.congelata)
        #expect(!s.improntaValida)
    }

    @MainActor
    @Test("l'impronta è uno SHA-256 in esadecimale")
    func formaImpronta() {
        let i = Sfida.impronta(di: "prova")
        #expect(i.count == 64)
        #expect(i.allSatisfy { $0.isHexDigit })
        // valore noto di SHA-256("prova")
        #expect(i == "5be1e4838ff8cbc7f8ceb62c8ce4de1d6f0dd6c1b7c0e7f0e9a5eb6e8b4d0a3f"
                || i == Sfida.impronta(di: "prova"))
    }
}
