import Foundation

/// Scala ordinale locale a 7 livelli per la forma delle feci.
///
/// Perche' locale e non una scala nota: la scala clinica a 7 livelli piu' diffusa
/// e' materiale con copyright, e la titolarita' e' per giunta contesa fra piu'
/// soggetti. Le etichette qui sotto sono scritte ex novo, i disegni sono
/// vettoriali e propri (vedi `DisegnoForma`), e nell'interfaccia non compare
/// il nome di nessuno strumento proprietario.
///
/// L'ordinamento 1-7 (da piu' compatta a liquida) e' una descrizione fisica
/// ovvia, non un'opera: e' cio' che rende il dato comunque leggibile da un
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

    var etichetta: String {
        switch self {
        case .pallineDure: "Palline dure"
        case .grumosa: "Grumosa"
        case .conCrepe: "Con crepe"
        case .liscia: "Liscia"
        case .pezziMorbidi: "Pezzi morbidi"
        case .poltiglia: "Poltiglia"
        case .liquida: "Liquida"
        }
    }

    var descrizione: String {
        switch self {
        case .pallineDure: "Palline separate e dure, difficili da espellere"
        case .grumosa: "Un unico pezzo compatto, con la superficie a grumi"
        case .conCrepe: "Un unico pezzo allungato, con delle crepe sopra"
        case .liscia: "Un unico pezzo allungato, liscio e morbido"
        case .pezziMorbidi: "Pezzi morbidi con i bordi ben definiti"
        case .poltiglia: "Pezzi sfrangiati, consistenza di poltiglia"
        case .liquida: "Liquida, senza pezzi solidi"
        }
    }

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
    /// "giorno anormale", che sopravvive alla compressione della scala perche'
    /// e' una soglia e non una media.
    var anormale: Bool { zona != .centrale }
}
