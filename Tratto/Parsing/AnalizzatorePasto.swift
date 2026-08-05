import Foundation
import FoundationModels

/// Trasforma una frase dettata in una lista di ingredienti dell'ontologia.
///
/// Il modello on-device di sistema fa da traduttore dal parlato colloquiale a
/// frammenti puliti; il riconoscimento vero e proprio resta al confronto
/// deterministico con l'ontologia. Cosi' il testo grezzo si conserva sempre,
/// niente entra nel diario senza essere passato dal vocabolario, e se il
/// modello non c'e' (dispositivo senza Apple Intelligence, lingua non
/// supportata) l'app funziona identica, solo un po' meno indulgente sulle
/// perifrasi.
@Generable
struct FrammentiPasto {
    @Guide(description: "Ogni cibo o bevanda nominato nella frase, al singolare e senza articoli. Solo il nome dell'alimento.")
    var cibi: [String]
}

struct EsitoAnalisi: Sendable, Equatable {
    var riconosciuti: [Corrispondenza.Riconosciuto]
    /// Frammenti che sembrano cibi ma non stanno nell'ontologia: diventano la
    /// proposta "aggiungi questo ingrediente", mai una voce silenziosa.
    var candidatiNuovi: [String]
    var testoGrezzo: String
    var modelloUsato: Bool
}

actor AnalizzatorePasto {

    private let corrispondenza: Corrispondenza

    init(corrispondenza: Corrispondenza) {
        self.corrispondenza = corrispondenza
    }

    static var modelloDisponibile: Bool {
        let modello = SystemLanguageModel.default
        guard case .available = modello.availability else { return false }
        return modello.supportsLocale(Locale(identifier: "it_IT"))
    }

    static var motivoIndisponibilita: String? {
        let modello = SystemLanguageModel.default
        switch modello.availability {
        case .available:
            return modello.supportsLocale(Locale(identifier: "it_IT"))
                ? nil
                : "Il modello del dispositivo non supporta l'italiano."
        case .unavailable(.deviceNotEligible):
            return "Questo dispositivo non supporta il modello di sistema."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence è disattivata nelle impostazioni di sistema."
        case .unavailable(.modelNotReady):
            return "Il modello di sistema si sta ancora scaricando."
        case .unavailable:
            return "Il modello di sistema non è disponibile."
        @unknown default:
            return "Il modello di sistema non è disponibile."
        }
    }

    private static let istruzioni = """
    Ricevi una frase in italiano con cui una persona descrive quello che ha mangiato.
    Elenca i cibi e le bevande nominati, uno per voce, al singolare e senza articoli \
    né quantità. Non aggiungere ingredienti che non sono scritti nella frase e non \
    provare a indovinare la ricetta: se la frase dice "pizza", la risposta è "pizza", \
    non la lista dei suoi ingredienti. Se la frase non nomina nessun cibo, restituisci \
    una lista vuota.
    """

    /// Il confronto con l'ontologia sul testo grezzo viene fatto sempre.
    /// Il modello aggiunge solo quello che la scansione diretta non ha visto.
    func analizza(_ testo: String) async -> EsitoAnalisi {
        let diretta = corrispondenza.analizza(testo)
        var riconosciuti = diretta.riconosciuti
        var visti = Set(riconosciuti.map(\.identificativo))
        var candidati: [String] = []
        var modelloUsato = false

        if Self.modelloDisponibile, !testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                let sessione = LanguageModelSession(instructions: Self.istruzioni)
                let risposta = try await sessione.respond(to: testo, generating: FrammentiPasto.self)
                modelloUsato = true
                for frammento in risposta.content.cibi {
                    let esito = corrispondenza.analizza(frammento, distanzaMassima: 1)
                    if esito.riconosciuti.isEmpty {
                        let pulito = frammento.trimmingCharacters(in: .whitespacesAndNewlines)
                        if pulito.count >= 3, !candidati.contains(where: { $0.caseInsensitiveCompare(pulito) == .orderedSame }) {
                            candidati.append(pulito)
                        }
                    } else {
                        for r in esito.riconosciuti where visti.insert(r.identificativo).inserted {
                            riconosciuti.append(r)
                        }
                    }
                }
            } catch {
                // Il modello puo' rifiutare o non essere pronto: non e' un errore
                // dell'utente e non deve bloccare il salvataggio.
                modelloUsato = false
            }
        }

        if !modelloUsato {
            // Senza modello, i frammenti non riconosciuti della scansione diretta
            // sono l'unica fonte di candidati.
            candidati = diretta.nonRiconosciuti
                .filter { $0.count >= 4 }
                .reduce(into: [String]()) { acc, x in if !acc.contains(x) { acc.append(x) } }
        }

        return EsitoAnalisi(riconosciuti: riconosciuti,
                            candidatiNuovi: candidati,
                            testoGrezzo: testo,
                            modelloUsato: modelloUsato)
    }
}
