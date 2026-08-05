import Foundation

/// Una codifica di un'osservazione, nella forma che FHIR chiama `Coding`.
///
/// Il modello tiene un ARRAY di codifiche fin dalla prima versione dello schema,
/// non una sola. La ragione e' che la codifica di questo dominio e' asimmetrica
/// e verificata come tale:
///
///  - la forma delle feci ha un concetto SNOMED CT (443172007) ma **nessun**
///    codice LOINC: l'unico "Bristol" presente in LOINC e' una marca di sigarette;
///  - il dolore su scala numerica 0-10 ha un codice LOINC (72514-3) e non ha
///    bisogno di SNOMED;
///  - la frequenza delle evacuazioni ha entrambi (SNOMED 249521002; LOINC 80261-1,
///    che pero' e' ordinale a cinque intervalli e perde informazione).
///
/// SNOMED CT non e' libero in Italia (l'Italia non e' membro, serve una licenza
/// Affiliate), quindi le codifiche esterne sono opzionali e spente di default,
/// mentre una codifica locale e' **sempre** presente. Senza questa scelta presa
/// subito, un rifiuto o un costo di licenza renderebbe inesportabile un archivio
/// gia' pieno.
nonisolated struct Codifica: Codable, Hashable, Sendable {
    var sistema: String
    var codice: String
    var etichetta: String

    static let sistemaLocale = "https://nerln.dev/tratto/CodeSystem/osservazioni"
    static let snomed = "http://snomed.info/sct"
    static let loinc = "http://loinc.org"

    static func locale(_ codice: String, _ etichetta: String) -> Codifica {
        Codifica(sistema: sistemaLocale, codice: codice, etichetta: etichetta)
    }
}

/// I concetti che l'app sa osservare, con le loro codifiche.
nonisolated enum Concetto: String, CaseIterable, Sendable {
    case formaFecale
    case frequenzaEvacuazioni
    case dolorePeggiore24h
    case urgenza
    case gonfiore
    case giornoAnormale

    var etichetta: String {
        switch self {
        case .formaFecale: "Forma delle feci (scala locale 1-7)"
        case .frequenzaEvacuazioni: "Numero di evacuazioni al giorno"
        case .dolorePeggiore24h: "Peggior dolore addominale nelle ultime 24 ore (0-10)"
        case .urgenza: "Urgenza percepita (0-10)"
        case .gonfiore: "Gonfiore percepito (0-10)"
        case .giornoAnormale: "Giornata con almeno un'evacuazione fuori dall'intervallo centrale"
        }
    }

    /// Sempre presente, sempre nostra, sempre esportata.
    var codificaLocale: Codifica {
        .locale(rawValue, etichetta)
    }

    /// Aggiunte solo se l'utente attiva le codifiche esterne. Nessun codice qui
    /// e' inventato: quelli assenti sono assenti perche' non esistono.
    var codificheEsterne: [Codifica] {
        switch self {
        case .formaFecale:
            // Nessun codice LOINC esiste per questa scala. Solo SNOMED.
            [Codifica(sistema: Codifica.snomed, codice: "443172007",
                      etichetta: "Bristol stool form score")]
        case .frequenzaEvacuazioni:
            [Codifica(sistema: Codifica.snomed, codice: "249521002",
                      etichetta: "Frequency of bowel action")]
        case .dolorePeggiore24h:
            [Codifica(sistema: Codifica.loinc, codice: "72514-3",
                      etichetta: "Pain severity - 0-10 verbal numeric rating [Score] - Reported")]
        case .urgenza, .gonfiore, .giornoAnormale:
            // Nessuna codifica pubblica adeguata: resta solo quella locale.
            []
        }
    }

    func codifiche(includiEsterne: Bool) -> [Codifica] {
        includiEsterne ? [codificaLocale] + codificheEsterne : [codificaLocale]
    }

    /// Nota da stampare accanto al dato quando si esporta, perche' chi legge
    /// sappia che scala ha in mano.
    var notaPerIlClinico: String? {
        switch self {
        case .formaFecale:
            "Scala ordinale a 7 livelli con etichette e illustrazioni proprie, "
            + "ordinata dalla forma più compatta (1) alla liquida (7). "
            + "Non è la scala di Bristol e i valori non vanno letti come tali."
        case .dolorePeggiore24h:
            "Scala numerica 0-10 auto-riferita, una rilevazione al giorno."
        default:
            nil
        }
    }
}
