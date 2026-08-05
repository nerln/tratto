import Testing
import Foundation
@testable import Tratto

/// Gli oracoli sono esterni al codice sotto prova.
///
/// Per i casi senza pareggi ne' ex aequo: le tavole classiche di Wilcoxon, che
/// coincidono anche con `scipy.stats.wilcoxon(mode="exact")`.
///
/// Per i casi con pareggi o ex aequo: l'enumerazione di tutti i 2^n
/// assegnamenti di segno sui ranghi osservati, calcolata a parte in Python. Li'
/// scipy diverge, perche' la sua modalita' esatta usa la tavola senza ex aequo:
/// e' documentato come non esatto in presenza di pareggi.
@Suite("Test esatti su poche coppie")
struct TestEsattiTests {

    // MARK: - Test dei segni

    @Test("con sei concordanze su sei il p bilaterale è 2/64")
    func segniUnanimi() throws {
        let e = try #require(TestEsatti.testDeiSegni(differenze: [1, 2, 3, 0.5, 4, 1.5]))
        #expect(e.positivi == 6)
        #expect(e.negativi == 0)
        #expect(abs(e.pBilaterale - 2.0 / 64.0) < 1e-12)
        #expect(abs(e.pMinimoRaggiungibile - 2.0 / 64.0) < 1e-12)
    }

    @Test("cinque concordanze su sei non bastano: p = 0,21875")
    func segniQuasiUnanimi() throws {
        let e = try #require(TestEsatti.testDeiSegni(differenze: [1, 2, 3, -0.5, 4, 1.5]))
        #expect(abs(e.pBilaterale - 0.21875) < 1e-12)
    }

    @Test("con cinque coppie il minimo raggiungibile è già sopra 0,05")
    func cinqueCoppieNonBastano() throws {
        let e = try #require(TestEsatti.testDeiSegni(differenze: [1, 2, 3, 4, 5]))
        #expect(abs(e.pMinimoRaggiungibile - 0.0625) < 1e-12)
        #expect(e.pMinimoRaggiungibile > 0.05)
    }

    @Test("i pareggi tolgono coppie e alzano il pavimento del p")
    func pareggiUccidonoLEsperimento() throws {
        // sei coppie di cui due nulle: restano quattro, minimo bilaterale 0,125
        let e = try #require(TestEsatti.testDeiSegni(differenze: [1, 2, 0, 3, 0, 4]))
        #expect(e.pareggi == 2)
        #expect(e.coppieUsate == 4)
        #expect(abs(e.pMinimoRaggiungibile - 0.125) < 1e-12)
    }

    @Test("il coefficiente binomiale è esatto anche su valori grandi")
    func binomiale() {
        #expect(TestEsatti.binomiale(6, 0) == 1)
        #expect(TestEsatti.binomiale(6, 3) == 20)
        #expect(TestEsatti.binomiale(10, 5) == 252)
        #expect(TestEsatti.binomiale(20, 10) == 184_756)
        #expect(TestEsatti.binomiale(6, 7) == 0)
    }

    // MARK: - Wilcoxon

    /// Dodici differenze con un pareggio, segni misti e parecchi ex aequo:
    /// è il caso in cui la tavola classica dà il numero sbagliato.
    /// Valori attesi da enumerazione dei 2^n segni: 0,0478515625 con Pratt,
    /// 0,046875 escludendo gli zeri.
    private let conPareggi: [Double] = [-4, -2, 0, 3, -5, -1, 1, -4, -4, -3, 2, -4]

    @Test("con la convenzione di Pratt il valore coincide con l'enumerazione")
    func wilcoxonPratt() throws {
        let e = try #require(TestEsatti.wilcoxon(differenze: conPareggi, pareggi: .pratt))
        #expect(e.pareggi == 1)
        #expect(e.ranghiConExAequo)
        #expect(abs(e.pBilaterale - 0.0478515625) < 1e-9,
                "atteso 0,0478515625, ottenuto \(e.pBilaterale)")
    }

    @Test("escludendo gli zeri il valore coincide con l'enumerazione")
    func wilcoxonEsclusione() throws {
        let e = try #require(TestEsatti.wilcoxon(differenze: conPareggi, pareggi: .escludi))
        #expect(e.coppieUsate == 11)
        #expect(abs(e.pBilaterale - 0.046875) < 1e-9,
                "atteso 0,046875, ottenuto \(e.pBilaterale)")
    }

    @Test("con molti ex aequo la tavola classica darebbe un valore diverso")
    func exAequoNonUsanoLaTavola() throws {
        // |d| = 3,3,3,1,1,2,2,2,4 -> ranghi medi 7,7,7,1.5,1.5,4,4,4,9
        // W- = 3, e i sottoinsiemi con somma <= 3 sono 4 su 512: p = 2*4/512
        let e = try #require(TestEsatti.wilcoxon(differenze: [3, 3, 3, -1, -1, 2, 2, 2, 4],
                                                 pareggi: .escludi))
        #expect(e.ranghiConExAequo)
        #expect(abs(e.pBilaterale - 0.015625) < 1e-9,
                "atteso 0,015625 per enumerazione, ottenuto \(e.pBilaterale)")
        // la tavola senza ex aequo darebbe 10/512 = 0,01953125
        #expect(abs(e.pBilaterale - 0.01953125) > 1e-6)
    }

    @Test("la distribuzione nulla somma a 2^n")
    func distribuzioneCompleta() {
        for n in 1...10 {
            let ranghi = (1...n).map(Double.init)
            let d = TestEsatti.distribuzioneNulla(ranghi)
            let totale = d.values.reduce(0, +)
            #expect(abs(totale - pow(2, Double(n))) < 1e-6, "n=\(n)")
        }
    }

    @Test("senza ex aequo la distribuzione coincide con la tavola classica")
    func coincideConLaTavola() throws {
        // n = 6, W minimo = 0 -> p bilaterale 2/64 = 0,03125
        let e = try #require(TestEsatti.wilcoxon(differenze: [1, 2, 3, 4, 5, 6], pareggi: .escludi))
        #expect(abs(e.pBilaterale - 0.03125) < 1e-12)
        // n = 8, W = 0 -> 2/256
        let e8 = try #require(TestEsatti.wilcoxon(differenze: [1, 2, 3, 4, 5, 6, 7, 8], pareggi: .escludi))
        #expect(abs(e8.pBilaterale - 2.0 / 256.0) < 1e-12)
    }

    @Test("i ranghi medi gestiscono gli ex aequo")
    func ranghi() {
        #expect(TestEsatti.ranghiMedi([3, 1, 2]) == [3, 1, 2])
        #expect(TestEsatti.ranghiMedi([1, 1, 3]) == [1.5, 1.5, 3])
        #expect(TestEsatti.ranghiMedi([5, 5, 5, 5]) == [2.5, 2.5, 2.5, 2.5])
    }

    @Test("lo stimatore di Hodges-Lehmann è la mediana delle medie di Walsh")
    func hodgesLehmann() throws {
        let e = try #require(TestEsatti.wilcoxon(differenze: [1, 2, 3, 4, 5, 6], pareggi: .escludi))
        let hl = try #require(e.stimaHodgesLehmann)
        #expect(abs(hl - 3.5) < 1e-9)
    }

    @Test("l'intervallo dichiara la confidenza effettiva, che a sei coppie non è il 95%")
    func confidenzaEffettiva() throws {
        let e = try #require(TestEsatti.wilcoxon(differenze: [1, 2, 3, 4, 5, 6], pareggi: .escludi))
        let i = try #require(e.intervallo)
        #expect(i.confidenza != 0.95)
        #expect(i.confidenza > 0.9 && i.confidenza < 1.0)
        #expect(i.basso <= i.alto)
        // i due livelli raggiungibili a sei coppie
        #expect(abs(i.confidenza - 0.96875) < 1e-9 || abs(i.confidenza - 0.9375) < 1e-9,
                "confidenza inattesa: \(i.confidenza)")
    }

    // MARK: - Potenza

    @Test("con sei blocchi bilaterali serve l'unanimità, e la potenza è p^6")
    func potenzaUnanimita() throws {
        let p = try #require(TestEsatti.potenzaTestDeiSegni(blocchi: 6, probabilitaConcordanza: 0.8))
        #expect(abs(p - pow(0.8, 6)) < 1e-9)
        // il numero da mostrare all'utente: circa il 26%
        #expect(abs(p - 0.262144) < 1e-6)
    }

    @Test("la potenza cresce con la probabilità di concordanza, ma resta bassa")
    func potenzaCresce() throws {
        let p7 = try #require(TestEsatti.potenzaTestDeiSegni(blocchi: 6, probabilitaConcordanza: 0.7))
        let p9 = try #require(TestEsatti.potenzaTestDeiSegni(blocchi: 6, probabilitaConcordanza: 0.9))
        #expect(p7 < p9)
        #expect(p7 < 0.15)
        #expect(p9 < 0.55)
    }

    @Test("a sei blocchi unilaterale e bilaterale chiedono entrambi l'unanimità")
    func unilateraleASei() throws {
        // 5 concordanze su 6 danno p unilaterale = 7/64 = 0,109: non basta
        // nemmeno in unilaterale. La differenza fra le due ipotesi compare
        // solo da otto blocchi in su.
        let bi = try #require(TestEsatti.potenzaTestDeiSegni(
            blocchi: 6, probabilitaConcordanza: 0.8, unilaterale: false))
        let uni = try #require(TestEsatti.potenzaTestDeiSegni(
            blocchi: 6, probabilitaConcordanza: 0.8, unilaterale: true))
        #expect(uni == bi)
    }

    @Test("a otto blocchi l'unilaterale tollera una discordanza e il bilaterale no")
    func unilateraleAOtto() throws {
        let bi = try #require(TestEsatti.potenzaTestDeiSegni(
            blocchi: 8, probabilitaConcordanza: 0.8, unilaterale: false))
        let uni = try #require(TestEsatti.potenzaTestDeiSegni(
            blocchi: 8, probabilitaConcordanza: 0.8, unilaterale: true))
        #expect(uni > bi)
    }

    @Test("sotto i sei blocchi il bilaterale non può mai essere significativo")
    func minimoBlocchi() {
        #expect(TestEsatti.blocchiMinimi(alfa: 0.05, unilaterale: false) == 6)
        #expect(TestEsatti.blocchiMinimi(alfa: 0.05, unilaterale: true) == 5)
    }

    @Test("nove blocchi sono il primo numero che tollera una discordanza")
    func noveBlocchi() {
        // con 9 blocchi, 8 concordanze su 9 danno p bilaterale = 2*(9+1)/512
        let coda = (TestEsatti.binomiale(9, 8) + TestEsatti.binomiale(9, 9)) / pow(2, 9)
        #expect(2 * coda <= 0.05)
        // con 8 blocchi, 7 su 8 non basta
        let coda8 = (TestEsatti.binomiale(8, 7) + TestEsatti.binomiale(8, 8)) / pow(2, 8)
        #expect(2 * coda8 > 0.05)
    }
}
