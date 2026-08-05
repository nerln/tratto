import Testing
import Foundation
@testable import Tratto

/// Un sottoinsieme dell'ontologia vera, con le stesse insidie: voci che si
/// contengono a vicenda ("pasta" dentro "pasta integrale"), voci multiparola,
/// accenti, e nomi che nel 2020 stavano in due anagrafiche diverse.
private let voci: [Corrispondenza.Voce] = [
    .init(identificativo: "pasta_integrale", nome: "Pasta integrale",
          forme: ["Pasta integrale", "pasta_integrale"]),
    .init(identificativo: "pasta_di_grano", nome: "Pasta", forme: ["Pasta", "pasta"]),
    .init(identificativo: "riso", nome: "Riso", forme: ["Riso", "riso"]),
    .init(identificativo: "mela", nome: "Mela", forme: ["Mela", "mela"]),
    .init(identificativo: "finocchio", nome: "Finocchio", forme: ["Finocchio", "finocchio"]),
    .init(identificativo: "zucchina", nome: "Zucchina", forme: ["Zucchina", "zucchine"]),
    .init(identificativo: "olio_di_oliva", nome: "Olio d'oliva",
          forme: ["Olio d'oliva", "olio"]),
    .init(identificativo: "parmigiano", nome: "Parmigiano", forme: ["Parmigiano", "parmigiano"]),
    .init(identificativo: "pollo", nome: "Pollo",
          forme: ["Pollo", "fettina_pollo", "pollo_allo_spiedo", "cosciotti_pollo"]),
    .init(identificativo: "caffe", nome: "Caffè", forme: ["Caffè", "caffè"]),
    .init(identificativo: "latte_senza_lattosio", nome: "Latte senza lattosio",
          forme: ["Latte senza lattosio", "latte_senza_lattosio"]),
]

/// Le voci con la forma piu' lunga per prime, come fa la vista.
private var motore: Corrispondenza {
    Corrispondenza(voci: voci.sorted { ($0.forme.map(\.count).max() ?? 0) > ($1.forme.map(\.count).max() ?? 0) })
}

@Suite("Riconoscimento degli ingredienti")
struct CorrispondenzaTests {

    @Test("riconosce una frase semplice")
    func semplice() {
        let e = motore.analizza("riso e mela")
        #expect(Set(e.riconosciuti.map(\.identificativo)) == ["riso", "mela"])
    }

    @Test("la voce piu' lunga vince su quella che ci sta dentro")
    func specificitaVince() {
        let e = motore.analizza("pasta integrale al pomodoro")
        #expect(e.riconosciuti.map(\.identificativo).contains("pasta_integrale"))
        #expect(!e.riconosciuti.map(\.identificativo).contains("pasta_di_grano"))
    }

    @Test("i plurali italiani vengono ricondotti al singolare")
    func plurali() {
        #expect(motore.analizza("insalata di finocchi").riconosciuti
            .map(\.identificativo).contains("finocchio"))
        #expect(motore.analizza("le zucchine").riconosciuti
            .map(\.identificativo).contains("zucchina"))
    }

    @Test("gli accenti non contano")
    func accenti() {
        #expect(motore.analizza("un caffe").riconosciuti.map(\.identificativo).contains("caffe"))
        #expect(motore.analizza("un caffè").riconosciuti.map(\.identificativo).contains("caffe"))
    }

    @Test("i termini delle due anagrafiche del 2020 confluiscono nella stessa voce")
    func sinonimiLegacy() {
        for testo in ["fettina di pollo", "pollo allo spiedo", "pollo"] {
            #expect(motore.analizza(testo).riconosciuti.map(\.identificativo).contains("pollo"),
                    "«\(testo)» dovrebbe risolvere su pollo")
        }
    }

    @Test("una voce multiparola viene riconosciuta per intero")
    func multiparola() {
        let e = motore.analizza("latte senza lattosio con i cereali")
        #expect(e.riconosciuti.map(\.identificativo).contains("latte_senza_lattosio"))
    }

    @Test("le parole di servizio non diventano ingredienti")
    func paroleDiServizio() {
        let e = motore.analizza("a pranzo ho mangiato un po' di riso")
        #expect(e.riconosciuti.map(\.identificativo) == ["riso"])
        #expect(!e.nonRiconosciuti.contains("pranzo"))
        #expect(!e.nonRiconosciuti.contains("mangiato"))
    }

    @Test("un cibo fuori catalogo finisce fra i non riconosciuti, non fra gli ingredienti")
    func fuoriCatalogo() {
        let e = motore.analizza("riso e salmone affumicato")
        #expect(e.riconosciuti.map(\.identificativo) == ["riso"])
        #expect(e.nonRiconosciuti.contains("salmone"))
    }

    @Test("un refuso viene recuperato ma marcato come approssimato")
    func refuso() throws {
        let e = motore.analizza("parmiggiano")
        let r = try #require(e.riconosciuti.first)
        #expect(r.identificativo == "parmigiano")
        #expect(r.tipo == .approssimata)
    }

    @Test("parole corte simili non vengono confuse fra loro")
    func nienteFalsiPositiviCorti() {
        // «viso» e «peso» non devono diventare «riso»: su parole brevi la
        // somiglianza non basta
        #expect(motore.analizza("viso").riconosciuti.isEmpty)
        #expect(motore.analizza("peso").riconosciuti.isEmpty)
    }

    @Test("lo stesso ingrediente nominato due volte compare una volta sola")
    func nienteDoppioni() {
        let e = motore.analizza("riso, e poi ancora riso")
        #expect(e.riconosciuti.filter { $0.identificativo == "riso" }.count == 1)
    }

    @Test("una frase senza cibo non produce niente")
    func nessunCibo() {
        let e = motore.analizza("oggi non ho avuto fame")
        #expect(e.riconosciuti.isEmpty)
    }

    @Test("la normalizzazione toglie punteggiatura e accenti")
    func normalizzazione() {
        #expect(Corrispondenza.normalizza("Olio d'oliva!") == "olio_d_oliva")
        #expect(Corrispondenza.normalizza("  Caffè   ") == "caffe")
        #expect(Corrispondenza.normalizza("") == "")
    }

    @Test("la distanza di modifica si ferma appena supera il limite")
    func distanza() {
        #expect(Corrispondenza.distanza("riso", "riso", limite: 2) == 0)
        #expect(Corrispondenza.distanza("riso", "viso", limite: 2) == 1)
        #expect(Corrispondenza.distanza("riso", "elefante", limite: 2) > 2)
    }
}

@Suite("Esportazione")
struct EsportazioneTests {

    private func istantanea() -> Esportazione.Istantanea {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        let g = c.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 9, minute: 30))!
        return .init(
            eventi: [.init(quando: g, forma: 6, urgenza: 7, dolore: 3, sangue: false,
                           note: "con una virgola, e delle \"virgolette\"")],
            pasti: [.init(quando: g, fascia: "Pranzo", stato: "registrato",
                          ingredienteId: "riso", ingredienteNome: "Riso", categoria: "Cereali",
                          quantita: "normale", testoGrezzo: "riso in bianco")],
            giorni: [.init(giorno: g, dolore: 5, gonfiore: 2, oreSonno: 7.5, stress: 4,
                           caffe: 2, alcol: false, esercizio: true, atipica: false)],
            riepilogo: .vuoto, codificheEsterne: false)
    }

    @Test("il CSV protegge virgole e virgolette dentro i campi")
    func csvSicuro() {
        let csv = Esportazione.csvEventi(istantanea())
        #expect(csv.contains("\"con una virgola, e delle \"\"virgolette\"\"\""))
        #expect(csv.split(separator: "\n").count == 2)
    }

    @Test("il CSV dei pasti ha una riga per ingrediente")
    func csvPasti() {
        let csv = Esportazione.csvPasti(istantanea())
        #expect(csv.contains("riso,Riso,Cereali,normale"))
    }

    @Test("il JSON si rilegge e contiene le note sulle scale")
    func json() throws {
        let dati = try Esportazione.json(istantanea())
        let letto = try #require(try JSONSerialization.jsonObject(with: dati) as? [String: Any])
        #expect(letto["applicazione"] as? String == "Tratto")
        let scale = try #require(letto["scale"] as? [String: Any])
        let forma = try #require(scale["forma"] as? String)
        #expect(forma.contains("Non è la scala di Bristol"))
    }

    @Test("senza codifiche esterne l'export porta solo quella locale")
    func fhirSoloLocale() throws {
        let dati = try Esportazione.fhir(istantanea())
        let testo = String(decoding: dati, as: UTF8.self)
        #expect(testo.contains("nerln.dev/tratto/CodeSystem"))
        #expect(!testo.contains("snomed.info"))
        #expect(!testo.contains("loinc.org"))
    }

    @Test("con le codifiche esterne compaiono SNOMED per la forma e LOINC per il dolore")
    func fhirConEsterne() throws {
        var i = istantanea()
        i.codificheEsterne = true
        let testo = String(decoding: try Esportazione.fhir(i), as: UTF8.self)
        #expect(testo.contains("443172007"))
        #expect(testo.contains("72514-3"))
    }

    @Test("la forma delle feci non porta nessun codice LOINC, perche' non esiste")
    func nessunLoincPerLaForma() {
        let esterne = Concetto.formaFecale.codificheEsterne
        #expect(esterne.allSatisfy { $0.sistema != Codifica.loinc })
        #expect(esterne.contains { $0.sistema == Codifica.snomed && $0.codice == "443172007" })
    }

    @Test("ogni concetto ha sempre almeno la codifica locale")
    func codificaLocaleSempre() {
        for c in Concetto.allCases {
            #expect(!c.codifiche(includiEsterne: false).isEmpty)
            #expect(c.codifiche(includiEsterne: false).first?.sistema == Codifica.sistemaLocale)
        }
    }
}

@Suite("Modello")
struct ModelloTests {

    @Test("la fascia si deduce dall'orario")
    func fasce() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        func alle(_ ora: Int) -> Fascia {
            Fascia.dedotta(da: c.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: ora))!,
                           calendario: c)
        }
        #expect(alle(8) == .colazione)
        #expect(alle(13) == .pranzo)
        #expect(alle(20) == .cena)
        #expect(alle(23) == .spuntinoSera)
        #expect(alle(3) == .spuntinoSera)
    }

    @Test("le forme agli estremi sono fuori dall'intervallo centrale, quelle di mezzo no")
    func anormalita() {
        #expect(FormaFecale.pallineDure.anormale)
        #expect(FormaFecale.grumosa.anormale)
        #expect(!FormaFecale.conCrepe.anormale)
        #expect(!FormaFecale.liscia.anormale)
        #expect(!FormaFecale.pezziMorbidi.anormale)
        #expect(FormaFecale.poltiglia.anormale)
        #expect(FormaFecale.liquida.anormale)
    }

    @Test("i sette livelli hanno tutti un'etichetta e una descrizione diverse")
    func etichette() {
        let etichette = Set(FormaFecale.allCases.map(\.etichetta))
        let descrizioni = Set(FormaFecale.allCases.map(\.descrizione))
        #expect(etichette.count == 7)
        #expect(descrizioni.count == 7)
    }

    @Test("l'interfaccia non nomina nessuna scala proprietaria")
    func nessunNomeProprietario() {
        let testo = (FormaFecale.allCases.map { $0.etichetta + " " + $0.descrizione }
                     + [Testi.disclaimerBreve, Testi.disclaimerEsteso])
            .joined(separator: " ").lowercased()
        #expect(!testo.contains("bristol"))
        #expect(!testo.contains("roma iv"))
        #expect(!testo.contains("ibs-sss"))
    }

    @Test("un pasto «niente» conta come risolto anche senza ingredienti")
    func digiunoRisolto() {
        let p = Pasto(quando: .now, fascia: .colazione, stato: .digiuno)
        #expect(p.risolto)
        let vuoto = Pasto(quando: .now, fascia: .colazione, stato: .registrato)
        #expect(!vuoto.risolto)
    }

    @Test("la forma viene tenuta dentro l'intervallo valido")
    func formaLimitata() {
        #expect(EventoIntestinale(quando: .now, forma: 99).forma == 7)
        #expect(EventoIntestinale(quando: .now, forma: -3).forma == 1)
    }
}
