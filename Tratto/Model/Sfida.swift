import Foundation
import SwiftData
import CryptoKit

/// La fase 2: un confronto programmato invece che un diario osservato.
///
/// Serve perché l'osservazione passiva non produce quello che serve. Nei dati
/// del 2020 solo 19 ingredienti su 142 arrivavano a dieci esposizioni, e quelle
/// esposizioni erano quando capitava, insieme ad altri cibi, senza dose. Un
/// confronto programmato forza l'esposizione a un bersaglio scelto, in blocchi
/// di durata nota, alternati a blocchi di controllo.
///
/// La struttura viene da protocolli pubblicati e citabili (Whelan 2018;
/// Lomer 2023, CC BY): un bersaglio per volta, blocchi consecutivi, una pausa
/// fra un blocco e il successivo, e nessuna reintroduzione stabile finché tutti
/// i confronti non sono chiusi. Le durate però non sono quelle della
/// letteratura clinica: là il blocco è di 3 giorni, qui è più lungo, e per due
/// ragioni indipendenti. La prima è nei dati di questa persona:
/// l'autocorrelazione giornaliera è +0,51 a un giorno, +0,16 a tre e +0,05 a
/// quattro, quindi una pausa di 3 giorni lascia ancora dentro l'eco del blocco
/// precedente. La seconda è biologica: nel challenge in cieco pubblicato i
/// sintomi da lattosio compaiono al terzo giorno, quindi un blocco di 3 giorni
/// è troncato prima di poterli vedere.
///
/// Quello che questa app NON fa è decidere l'esito. Nei protocolli pubblicati
/// la positività si definisce con una soglia su uno strumento licenziato; qui
/// si mostrano le due serie affiancate, il p esatto, la convenzione usata e
/// l'intervallo, e il giudizio resta a chi legge.
@Model
final class Sfida {
    var identificativo: UUID = UUID()
    var titolo: String = ""
    /// L'ingrediente da testare, preso dall'ontologia.
    var bersaglioId: String = ""
    var bersaglioNome: String = ""
    /// L'ingrediente dei blocchi di confronto. Gli alimenti interi non si
    /// possono accecare, quindi questo non è un placebo: è un controllo
    /// temporale, cioè un blocco identico per struttura con un ingrediente che
    /// non si sospetta. Non elimina l'aspettativa, ma le dà qualcosa contro cui
    /// misurarsi. Senza, il tasso di falsi positivi atteso non è zero: nel
    /// challenge in cieco il controllo inerte ha «scatenato» sintomi nel 26%.
    var controlloId: String = ""
    var controlloNome: String = ""

    var esitoGrezzo: String = EsitoSfida.dolore.rawValue
    var direzioneGrezza: String = DirezioneIpotesi.bilaterale.rawValue
    var pareggiGrezzi: String = "pratt"

    var blocchiPrevisti: Int = 6
    var giorniPerBlocco: Int = 5
    var giorniDiPausa: Int = 4
    /// Quanti giorni scartare all'inizio di ogni blocco in fase di analisi.
    /// Non cambia niente per chi segue il protocollo: è solo una maschera sui
    /// dati, e serve a togliere la coda del blocco precedente.
    var giorniScartatiInTesta: Int = 1

    var iniziataIl: Date?
    var congelatoIl: Date?
    /// Impronta del protocollo al momento del congelamento. L'analisi si
    /// rifiuta di girare se il protocollo di adesso non corrisponde: è l'unico
    /// modo per rendere credibile una preregistrazione fatta da chi è insieme
    /// sperimentatore e soggetto.
    var improntaProtocollo: String?
    var semeRandomizzazione: UInt64 = 0
    var chiusa: Bool = false
    var note: String = ""
    var creataIl: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \BloccoSfida.sfida)
    var blocchi: [BloccoSfida]? = []

    init(titolo: String, bersaglioId: String, bersaglioNome: String,
         controlloId: String, controlloNome: String,
         esito: EsitoSfida = .dolore, direzione: DirezioneIpotesi = .bilaterale,
         blocchiPrevisti: Int = 6, giorniPerBlocco: Int = 5, giorniDiPausa: Int = 4) {
        self.identificativo = UUID()
        self.titolo = titolo
        self.bersaglioId = bersaglioId
        self.bersaglioNome = bersaglioNome
        self.controlloId = controlloId
        self.controlloNome = controlloNome
        self.esitoGrezzo = esito.rawValue
        self.direzioneGrezza = direzione.rawValue
        self.blocchiPrevisti = blocchiPrevisti
        self.giorniPerBlocco = giorniPerBlocco
        self.giorniDiPausa = giorniDiPausa
        self.creataIl = .now
    }

    var esito: EsitoSfida {
        get { EsitoSfida(rawValue: esitoGrezzo) ?? .dolore }
        set { esitoGrezzo = newValue.rawValue }
    }
    var direzione: DirezioneIpotesi {
        get { DirezioneIpotesi(rawValue: direzioneGrezza) ?? .bilaterale }
        set { direzioneGrezza = newValue.rawValue }
    }
    var convenzionePareggi: TestEsatti.Pareggi {
        get { TestEsatti.Pareggi(rawValue: pareggiGrezzi) ?? .pratt }
        set { pareggiGrezzi = newValue.rawValue }
    }

    var congelata: Bool { improntaProtocollo != nil }

    var blocchiOrdinati: [BloccoSfida] {
        (blocchi ?? []).sorted { $0.indice < $1.indice }
    }

    /// Il testo canonico da cui si calcola l'impronta. Deve contenere tutto
    /// quello che, se cambiasse dopo, renderebbe l'analisi non più quella
    /// dichiarata; e niente altro, altrimenti l'impronta cambia per motivi
    /// irrilevanti.
    var protocolloCanonico: String {
        let righe = [
            "bersaglio=\(bersaglioId)",
            "controllo=\(controlloId)",
            "esito=\(esitoGrezzo)",
            "direzione=\(direzioneGrezza)",
            "pareggi=\(pareggiGrezzi)",
            "blocchi=\(blocchiPrevisti)",
            "giorniPerBlocco=\(giorniPerBlocco)",
            "giorniDiPausa=\(giorniDiPausa)",
            "giorniScartatiInTesta=\(giorniScartatiInTesta)",
            "seme=\(semeRandomizzazione)",
            "sequenza=" + blocchiOrdinati.map { "\($0.indice):\($0.condizioneGrezza)" }
                .joined(separator: ","),
        ]
        return righe.joined(separator: "\n")
    }

    static func impronta(di testo: String) -> String {
        SHA256.hash(data: Data(testo.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// `true` quando il protocollo di adesso è ancora quello congelato.
    var improntaValida: Bool {
        guard let attesa = improntaProtocollo else { return false }
        return attesa == Self.impronta(di: protocolloCanonico)
    }
}

nonisolated enum EsitoSfida: String, CaseIterable, Identifiable, Sendable {
    /// Media del dolore 0-10 sui giorni del blocco. È metrico, quindi il
    /// confronto appaiato ha senso sulla magnitudine e non solo sul segno.
    case dolore
    /// Quota di giornate del blocco con almeno un'evacuazione fuori
    /// dall'intervallo centrale. È una soglia, quindi sopravvive alla
    /// compressione della scala ordinale.
    case giornateAnormali

    var id: String { rawValue }

    var chiaveNome: String {
        switch self {
        case .dolore: "Mean daily pain (0-10)"
        case .giornateAnormali: "Share of days outside the middle range"
        }
    }
}

nonisolated enum DirezioneIpotesi: String, CaseIterable, Identifiable, Sendable {
    case bilaterale
    case unilateraleAumento

    var id: String { rawValue }

    var chiaveNome: String {
        switch self {
        case .bilaterale: "Any difference (two-sided)"
        case .unilateraleAumento: "The target makes it worse (one-sided)"
        }
    }

    var unilaterale: Bool { self == .unilateraleAumento }
}

@Model
final class BloccoSfida {
    var indice: Int = 0
    var condizioneGrezza: String = CondizioneBlocco.bersaglio.rawValue
    var dal: Date = Date.distantPast
    var al: Date = Date.distantPast
    /// Quanti giorni del blocco sono stati seguiti come previsto.
    var giorniAderenti: Int = 0
    var chiuso: Bool = false
    var note: String = ""

    var sfida: Sfida?

    init(indice: Int, condizione: CondizioneBlocco, dal: Date, al: Date) {
        self.indice = indice
        self.condizioneGrezza = condizione.rawValue
        self.dal = dal
        self.al = al
    }

    var condizione: CondizioneBlocco {
        get { CondizioneBlocco(rawValue: condizioneGrezza) ?? .bersaglio }
        set { condizioneGrezza = newValue.rawValue }
    }
}

nonisolated enum CondizioneBlocco: String, CaseIterable, Sendable {
    case bersaglio
    case controllo

    var chiaveNome: String {
        switch self {
        case .bersaglio: "Target"
        case .controllo: "Comparison"
        }
    }
}
