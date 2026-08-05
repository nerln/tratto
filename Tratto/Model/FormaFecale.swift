import Foundation

/// Scala ordinale locale a 7 livelli per la forma delle feci.
///
/// Perché locale e non una scala nota: la scala clinica a 7 livelli più diffusa
/// è materiale con copyright, e la titolarità è per giunta contesa fra più
/// soggetti. Le etichette qui sotto sono scritte ex novo, i disegni sono
/// vettoriali e propri (vedi `DisegnoForma`), e nell'interfaccia non compare
/// il nome di nessuno strumento proprietario.
///
/// L'ordinamento 1-7 (da più compatta a liquida) è una descrizione fisica
/// ovvia, non un'opera: è ciò che rende il dato comunque leggibile da un
/// clinico e mappabile in fase di esportazione.
nonisolated enum FormaFecale: Int, CaseIterable, Identifiable, Codable, Sendable {
    case pallineDure = 1
    case grumosa = 2
    case conCrepe = 3
    case liscia = 4
    case pezziMorbidi = 5
    case poltiglia = 6
    case liquida = 7

    var id: Int { rawValue }

    /// La chiave è il testo inglese: è la convenzione dei cataloghi di stringhe
    /// e rende leggibile il codice senza dover aprire il catalogo.
    var chiaveEtichetta: String {
        switch self {
        case .pallineDure: "Hard pellets"
        case .grumosa: "Lumpy"
        case .conCrepe: "Cracked"
        case .liscia: "Smooth"
        case .pezziMorbidi: "Soft pieces"
        case .poltiglia: "Mushy"
        case .liquida: "Liquid"
        }
    }

    var chiaveDescrizione: String {
        switch self {
        case .pallineDure: "Separate hard pellets, hard to pass"
        case .grumosa: "One compact piece with a lumpy surface"
        case .conCrepe: "One long piece with cracks on the surface"
        case .liscia: "One long piece, smooth and soft"
        case .pezziMorbidi: "Soft pieces with clear-cut edges"
        case .poltiglia: "Ragged pieces, mushy texture"
        case .liquida: "Liquid, with no solid pieces"
        }
    }

    func etichetta(_ locale: Locale) -> String { testo(.init(chiaveEtichetta), locale) }
    func descrizione(_ locale: Locale) -> String { testo(.init(chiaveDescrizione), locale) }

    /// Raggruppamento grossolano, usato solo per i colori e per i riepiloghi.
    enum Zona: String, Sendable { case compatta, centrale, molle }

    var zona: Zona {
        switch self {
        case .pallineDure, .grumosa: .compatta
        case .conCrepe, .liscia, .pezziMorbidi: .centrale
        case .poltiglia, .liquida: .molle
        }
    }

    /// Fuori dall'intervallo centrale. Alimenta l'esito secondario binario
    /// "giornata anormale", che sopravvive alla compressione della scala perché
    /// è una soglia e non una media.
    var anormale: Bool { zona != .centrale }
}
