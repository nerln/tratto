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

    var chiaveEtichetta: String {
        switch self {
        case .formaFecale: "Stool form (local 1-7 scale)"
        case .frequenzaEvacuazioni: "Bowel movements per day"
        case .dolorePeggiore24h: "Worst abdominal pain in the last 24 hours (0-10)"
        case .urgenza: "Perceived urgency (0-10)"
        case .gonfiore: "Perceived bloating (0-10)"
        case .giornoAnormale: "Day with at least one bowel movement outside the middle range"
        }
    }

    func etichetta(_ locale: Locale) -> String { testo(.init(chiaveEtichetta), locale) }

    /// Sempre presente, sempre nostra, sempre esportata.
    /// L'etichetta dell'export resta in inglese: è il documento che può finire
    /// in mano a qualcuno che non parla la lingua di chi l'ha prodotto.
    var codificaLocale: Codifica {
        .locale(rawValue, testo(.init(chiaveEtichetta), Locale(identifier: "en")))
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

    /// La nota da stampare accanto al dato nel referto, nella lingua scelta.
    func notaPerIlClinico(_ locale: Locale) -> String? {
        chiaveNotaPerIlClinico.map { testo(.init($0), locale) }
    }

    /// Nota da stampare accanto al dato quando si esporta, perché chi legge
    /// sappia che scala ha in mano.
    var chiaveNotaPerIlClinico: String? {
        switch self {
        case .formaFecale:
            "A 7-level ordinal scale with its own labels and illustrations, ordered from the most compact form (1) to liquid (7). It is not the Bristol scale and the values must not be read as such."
        case .dolorePeggiore24h:
            "Self-reported 0-10 numeric scale, recorded once a day."
        default:
            nil
        }
    }
}
