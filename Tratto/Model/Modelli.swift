import Foundation
import SwiftData

// MARK: - Fasce della giornata

nonisolated enum Fascia: String, Codable, CaseIterable, Identifiable, Sendable {
    case colazione, spuntinoMattina, pranzo, merenda, cena, spuntinoSera

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .colazione: "Colazione"
        case .spuntinoMattina: "Spuntino del mattino"
        case .pranzo: "Pranzo"
        case .merenda: "Merenda"
        case .cena: "Cena"
        case .spuntinoSera: "Spuntino della sera"
        }
    }

    /// Ora indicativa usata solo per ordinare e per indovinare la fascia dall'orario.
    var oraTipica: Int {
        switch self {
        case .colazione: 8
        case .spuntinoMattina: 11
        case .pranzo: 13
        case .merenda: 17
        case .cena: 20
        case .spuntinoSera: 22
        }
    }

    /// Le fasce che ci si aspetta di avere risolte in una giornata completa.
    /// Gli spuntini non sono attesi: nel 2020 lo spuntino del mattino compare 1 volta su 59 giorni,
    /// pretenderlo produrrebbe una copertura sempre bassa e quindi inutile.
    static var attese: [Fascia] { [.colazione, .pranzo, .cena] }

    static func dedotta(da data: Date, calendario: Calendar = .current) -> Fascia {
        let ora = calendario.component(.hour, from: data)
        switch ora {
        case 5..<10: return .colazione
        case 10..<12: return .spuntinoMattina
        case 12..<15: return .pranzo
        case 15..<18: return .merenda
        case 18..<22: return .cena
        default: return .spuntinoSera
        }
    }
}

// MARK: - Ingredienti

/// Voce canonica dell'ontologia. Le due anagrafiche separate del 2020
/// ("alimenti" e "condimenti", che si sovrapponevano) confluiscono qui.
@Model
final class Ingrediente {
    #Unique<Ingrediente>([\.identificativo])

    var identificativo: String = ""
    var nome: String = ""
    var categoria: String = ""
    /// Etichette di conoscenza comune (lattosio, glutine, caffeina). Ipotesi
    /// modificabili dall'utente, non dati clinici: nessuna tabella FODMAP e'
    /// utilizzabile legalmente.
    var gruppi: [String] = []
    var sinonimi: [String] = []
    /// I termini del foglio di calcolo del 2020 che confluiscono in questa voce.
    var terminiLegacy: [String] = []
    /// Quante volte compariva nei pasti del 2020. Serve solo a ordinare i
    /// suggerimenti: non e' evidenza di niente.
    var esposizioni2020: Int = 0
    var creatoDallUtente: Bool = false
    var archiviato: Bool = false
    var creatoIl: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \VoceDiPasto.ingrediente)
    var voci: [VoceDiPasto]? = []

    init(identificativo: String, nome: String, categoria: String,
         gruppi: [String] = [], sinonimi: [String] = [],
         terminiLegacy: [String] = [], esposizioni2020: Int = 0,
         creatoDallUtente: Bool = false, creatoIl: Date = .now) {
        self.identificativo = identificativo
        self.nome = nome
        self.categoria = categoria
        self.gruppi = gruppi
        self.sinonimi = sinonimi
        self.terminiLegacy = terminiLegacy
        self.esposizioni2020 = esposizioni2020
        self.creatoDallUtente = creatoDallUtente
        self.creatoIl = creatoIl
    }

    /// Tutte le forme scritte sotto cui questa voce puo' essere riconosciuta.
    var formeRiconoscibili: [String] {
        ([nome, identificativo] + sinonimi + terminiLegacy)
    }
}

// MARK: - Pasti

enum StatoPasto: String, Codable, CaseIterable, Sendable {
    /// Ha mangiato e ha registrato cosa.
    case registrato
    /// Non ha mangiato in quella fascia. E' un dato, non un buco.
    case digiuno
    /// Ha mangiato ma non ricorda cosa. Anche questo e' un dato.
    case nonRicordato

    var nome: String {
        switch self {
        case .registrato: "Registrato"
        case .digiuno: "Niente"
        case .nonRicordato: "Non ricordo"
        }
    }
}

enum FontePasto: String, Codable, Sendable {
    case dettatura, solito, notifica, manuale, importato
}

enum Quantita: String, Codable, CaseIterable, Sendable {
    case poca, normale, tanta
    var nome: String {
        switch self {
        case .poca: "Poca"
        case .normale: "Normale"
        case .tanta: "Tanta"
        }
    }
}

@Model
final class Pasto {
    var identificativo: UUID = UUID()
    var quando: Date = Date.distantPast
    var fasciaGrezza: String = Fascia.pranzo.rawValue
    var statoGrezzo: String = StatoPasto.registrato.rawValue
    var fonteGrezza: String = FontePasto.manuale.rawValue
    /// Il testo cosi' come e' stato dettato o scritto. Si conserva sempre,
    /// anche quando l'estrazione degli ingredienti fallisce.
    var testoGrezzo: String = ""
    var note: String = ""
    var creatoIl: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \VoceDiPasto.pasto)
    var voci: [VoceDiPasto]? = []

    init(quando: Date, fascia: Fascia, stato: StatoPasto = .registrato,
         fonte: FontePasto = .manuale, testoGrezzo: String = "", note: String = "") {
        self.identificativo = UUID()
        self.quando = quando
        self.fasciaGrezza = fascia.rawValue
        self.statoGrezzo = stato.rawValue
        self.fonteGrezza = fonte.rawValue
        self.testoGrezzo = testoGrezzo
        self.note = note
        self.creatoIl = .now
    }

    var fascia: Fascia {
        get { Fascia(rawValue: fasciaGrezza) ?? .pranzo }
        set { fasciaGrezza = newValue.rawValue }
    }

    var stato: StatoPasto {
        get { StatoPasto(rawValue: statoGrezzo) ?? .registrato }
        set { statoGrezzo = newValue.rawValue }
    }

    var fonte: FontePasto {
        get { FontePasto(rawValue: fonteGrezza) ?? .manuale }
        set { fonteGrezza = newValue.rawValue }
    }

    var vociOrdinate: [VoceDiPasto] {
        (voci ?? []).sorted { $0.creatoIl < $1.creatoIl }
    }

    /// Un pasto conta come "risolto" ai fini della copertura se sappiamo
    /// che cosa e' successo in quella fascia, anche quando la risposta e' "niente".
    var risolto: Bool {
        switch stato {
        case .digiuno, .nonRicordato: true
        case .registrato: !(voci ?? []).isEmpty
        }
    }
}

@Model
final class VoceDiPasto {
    var identificativo: UUID = UUID()
    var quantitaGrezza: String = Quantita.normale.rawValue
    /// Il frammento di testo originale da cui questa voce e' stata riconosciuta.
    var testoOriginale: String = ""
    var creatoIl: Date = Date.distantPast

    var pasto: Pasto?
    var ingrediente: Ingrediente?

    init(ingrediente: Ingrediente, quantita: Quantita = .normale, testoOriginale: String = "") {
        self.identificativo = UUID()
        self.ingrediente = ingrediente
        self.quantitaGrezza = quantita.rawValue
        self.testoOriginale = testoOriginale
        self.creatoIl = .now
    }

    var quantita: Quantita {
        get { Quantita(rawValue: quantitaGrezza) ?? .normale }
        set { quantitaGrezza = newValue.rawValue }
    }
}

// MARK: - Eventi intestinali

@Model
final class EventoIntestinale {
    var identificativo: UUID = UUID()
    var quando: Date = Date.distantPast
    /// Scala ordinale locale a 7 livelli, con disegni ed etichette proprie.
    /// Vedi `FormaFecale`. Non e' una scala licenziata e nell'interfaccia
    /// non compare il nome di nessuno strumento proprietario.
    var forma: Int = 4
    var urgenza: Int?
    var dolore: Int?
    var sangue: Bool = false
    var note: String = ""
    var creatoIl: Date = Date.distantPast

    init(quando: Date, forma: Int, urgenza: Int? = nil, dolore: Int? = nil,
         sangue: Bool = false, note: String = "") {
        self.identificativo = UUID()
        self.quando = quando
        self.forma = min(max(forma, 1), 7)
        self.urgenza = urgenza
        self.dolore = dolore
        self.sangue = sangue
        self.note = note
        self.creatoIl = .now
    }

    /// Forma fuori dall'intervallo centrale. Serve all'esito secondario binario.
    var anormale: Bool { forma <= 2 || forma >= 6 }
}

// MARK: - Esito e contesto giornalieri

@Model
final class EsitoGiornaliero {
    #Unique<EsitoGiornaliero>([\.giorno])

    /// Mezzanotte del giorno di riferimento, nel fuso corrente.
    var giorno: Date = Date.distantPast
    /// Esito primario: peggior dolore addominale nelle ultime 24 ore, 0-10.
    /// E' l'unica variabile con un codice pubblico e libero (LOINC 72514-3).
    var dolorePeggiore: Int?
    var gonfiore: Int?
    var creatoIl: Date = Date.distantPast
    var aggiornatoIl: Date = Date.distantPast

    init(giorno: Date, dolorePeggiore: Int? = nil, gonfiore: Int? = nil) {
        self.giorno = giorno
        self.dolorePeggiore = dolorePeggiore
        self.gonfiore = gonfiore
        self.creatoIl = .now
        self.aggiornatoIl = .now
    }
}

@Model
final class ContestoGiornaliero {
    #Unique<ContestoGiornaliero>([\.giorno])

    var giorno: Date = Date.distantPast
    var oreSonno: Double?
    var stress: Int?
    var caffe: Int?
    var alcol: Bool?
    var esercizio: Bool?
    var giornataAtipica: Bool = false
    var note: String = ""
    var creatoIl: Date = Date.distantPast

    init(giorno: Date) {
        self.giorno = giorno
        self.creatoIl = .now
    }
}

// MARK: - Impostazioni

@Model
final class Impostazioni {
    var identificativo: String = "unica"
    var seedApplicato: Bool = false
    var versioneSeed: Int = 0
    /// Testo dei pasti ricorrenti, richiamabili con un tocco.
    var solitaColazione: String = ""
    var solitoSpuntino: String = ""
    var promemoriaAttivi: Bool = false
    var oraPromemoriaSera: Int = 22
    /// Aggiunge i coding esterni all'export. Spento di default: SNOMED CT
    /// richiede una licenza Affiliate in Italia.
    var codificheEsterneNellExport: Bool = false
    var primoAvvio: Date = Date.distantPast

    init() {
        self.identificativo = "unica"
        self.primoAvvio = .now
    }
}
