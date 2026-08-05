import Foundation
import SwiftUI

/// Selezione della lingua dell'interfaccia.
///
/// L'app nasce in inglese e l'italiano è una traduzione. Il motivo non è
/// estetico: il diario ha senso per chiunque debba tenerne uno, e l'inglese è
/// la lingua in cui le fonti cliniche di riferimento sono scritte.
///
/// Il modo in cui il cambio funziona è stato verificato invece che assunto:
///
///  - `.environment(\.locale)` **cambia davvero** la lingua delle stringhe
///    cercate da `Text` in SwiftUI, non solo il formato di numeri e date;
///  - `String(localized:locale:)` **non** cambia la lingua: restituisce sempre
///    quella del bundle, qualunque locale gli si passi;
///  - `LocalizedStringResource(_, locale:)` invece la cambia, ed è quindi la
///    via per le stringhe che non stanno dentro una vista (referto, export).
enum Lingua: String, CaseIterable, Identifiable, Sendable {
    case sistema
    case inglese
    case italiano

    var id: String { rawValue }

    var codice: String? {
        switch self {
        case .sistema: nil
        case .inglese: "en"
        case .italiano: "it"
        }
    }

    /// `nil` quando si segue il sistema: in quel caso la vista non tocca
    /// l'ambiente e lascia decidere a iOS o macOS.
    var locale: Locale? {
        codice.map(Locale.init(identifier:))
    }

    /// Il nome della lingua scritto nella lingua stessa, che è come si
    /// scrivono i selettori di lingua che funzionano.
    var nomeNativo: String {
        switch self {
        case .sistema: String(localized: "Follow the system")
        case .inglese: "English"
        case .italiano: "Italiano"
        }
    }

    static let chiavePreferenza = "tratto.lingua"

    static var salvata: Lingua {
        UserDefaults.standard.string(forKey: chiavePreferenza)
            .flatMap(Lingua.init(rawValue:)) ?? .sistema
    }

    func salva() {
        UserDefaults.standard.set(rawValue, forKey: Self.chiavePreferenza)
    }
}

/// Il locale effettivo con cui risolvere le stringhe fuori dalle viste.
@MainActor
enum LinguaCorrente {
    static var locale: Locale {
        Lingua.salvata.locale ?? Locale.current
    }
}

/// Risolve una chiave in una lingua precisa. Serve al referto, all'export e a
/// tutto ciò che non è una vista, dove l'ambiente di SwiftUI non arriva.
nonisolated func testo(_ chiave: String.LocalizationValue, _ locale: Locale) -> String {
    String(localized: LocalizedStringResource(chiave, locale: locale))
}

extension EnvironmentValues {
    /// La lingua scelta, per i punti in cui serve sapere quale sia e non solo
    /// avere le stringhe già tradotte.
    @Entry var lingua: Lingua = .sistema
}
