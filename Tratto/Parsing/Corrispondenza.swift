import Foundation

/// Riconosce ingredienti dell'ontologia dentro un testo italiano.
///
/// E' deterministico di proposito. La misura fatta sul modello on-device dice
/// perche': lasciato libero di produrre stringhe, inventa voci che non esistono
/// nel vocabolario (in una prova su quattro frasi ne ha aggiunte due, «birra» e
/// «arancia»); costretto da uno schema chiuso non inventa piu' nulla ma smette
/// di riconoscere, restituendo liste vuote su due frasi su tre. Nessuna delle
/// due modalita' regge da sola.
///
/// Quindi il modello, quando c'e', fa una cosa sola: proporre frammenti di
/// testo. La decisione su che cosa sia un ingrediente resta qui, in codice
/// ispezionabile, che sbaglia sempre allo stesso modo e si puo' provare.
nonisolated struct Corrispondenza: Sendable {

    struct Voce: Sendable, Hashable {
        var identificativo: String
        var nome: String
        var forme: [String]
    }

    struct Esito: Sendable, Equatable {
        var riconosciuti: [Riconosciuto]
        var nonRiconosciuti: [String]
    }

    struct Riconosciuto: Sendable, Equatable, Hashable {
        var identificativo: String
        var nome: String
        var testoOriginale: String
        /// `esatta` quando la forma coincide dopo la normalizzazione,
        /// `approssimata` quando e' stata accettata per somiglianza.
        var tipo: Tipo
        enum Tipo: String, Sendable { case esatta, approssimata }
    }

    private let indice: [String: Voce]
    private let vociPerId: [String: Voce]

    /// Parole che non vanno mai considerate ingredienti, per non trasformare
    /// "un po' di" in una voce di diario.
    static let parolePiene: Set<String> = [
        "di", "del", "della", "dello", "dei", "delle", "degli", "da", "dal", "con", "e", "ed",
        "il", "lo", "la", "i", "gli", "le", "un", "uno", "una", "un'", "al", "alla", "allo",
        "ai", "alle", "agli", "in", "su", "per", "po", "poco", "poca", "tanto", "tanta",
        "molto", "molta", "un_po", "solo", "anche", "piu", "meno", "stamattina", "stasera",
        "stanotte", "oggi", "ieri", "pranzo", "cena", "colazione", "merenda", "spuntino",
        "mangiato", "bevuto", "preso", "fetta", "fette", "fettina", "pezzo", "pezzi",
        "piatto", "porzione", "bicchiere", "tazza", "cucchiaio", "filo", "grattata",
        "circa", "quasi", "tipo", "come", "sempre", "solito", "solita", "bianco", "bianca",
    ]

    init(voci: [Voce]) {
        var indice: [String: Voce] = [:]
        var perId: [String: Voce] = [:]
        for v in voci {
            perId[v.identificativo] = v
            for forma in v.forme {
                for chiave in Self.chiaviPer(forma) where !chiave.isEmpty {
                    // La prima voce che rivendica una chiave la tiene: le voci
                    // arrivano gia' ordinate per specificita' dal chiamante.
                    if indice[chiave] == nil { indice[chiave] = v }
                }
            }
        }
        self.indice = indice
        self.vociPerId = perId
    }

    // MARK: - Normalizzazione

    static func normalizza(_ s: String) -> String {
        let senzaAccenti = s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                     locale: Locale(identifier: "it_IT"))
        let ammessi = senzaAccenti.map { c -> Character in
            c.isLetter || c.isNumber ? c : " "
        }
        return String(ammessi)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "_")
    }

    /// Varianti di una forma sotto cui accettarla, incluse quelle singolari e
    /// plurali generate con le regole piu' banali dell'italiano.
    static func chiaviPer(_ forma: String) -> Set<String> {
        let base = normalizza(forma)
        guard !base.isEmpty else { return [] }
        var chiavi: Set<String> = [base]
        // la variante senza underscore aiuta quando la forma e' multiparola
        chiavi.insert(base.replacingOccurrences(of: "_", with: ""))
        for variante in flessioni(base) { chiavi.insert(variante) }
        return chiavi
    }

    static func flessioni(_ parola: String) -> Set<String> {
        // si flette solo l'ultima parola di una forma composta
        let pezzi = parola.split(separator: "_").map(String.init)
        guard let ultima = pezzi.last, ultima.count >= 4 else { return [] }
        let prefisso = pezzi.dropLast().joined(separator: "_")
        var varianti: Set<String> = []
        let radice = String(ultima.dropLast())
        switch ultima.last {
        case "o": varianti.formUnion([radice + "i"])
        case "a": varianti.formUnion([radice + "e", radice + "i"])
        case "e": varianti.formUnion([radice + "i", radice + "a"])
        case "i": varianti.formUnion([radice + "o", radice + "e", radice + "a"])
        default: break
        }
        if ultima.hasSuffix("co") { varianti.insert(String(ultima.dropLast(2)) + "chi") }
        if ultima.hasSuffix("ca") { varianti.insert(String(ultima.dropLast(2)) + "che") }
        if ultima.hasSuffix("chi") { varianti.insert(String(ultima.dropLast(3)) + "co") }
        if ultima.hasSuffix("che") { varianti.insert(String(ultima.dropLast(3)) + "ca") }
        return Set(varianti.map { prefisso.isEmpty ? $0 : prefisso + "_" + $0 })
    }

    // MARK: - Riconoscimento

    /// Percorre il testo cercando le sequenze di parole piu' lunghe che
    /// corrispondono a una voce, poi scende a sequenze piu' corte.
    func analizza(_ testo: String, lunghezzaMassima: Int = 4,
                  distanzaMassima: Int = 2) -> Esito {
        let parole = Self.normalizza(testo).split(separator: "_").map(String.init)
        guard !parole.isEmpty else { return Esito(riconosciuti: [], nonRiconosciuti: []) }

        var riconosciuti: [Riconosciuto] = []
        var visti: Set<String> = []
        var nonRiconosciute: [String] = []
        var i = 0

        while i < parole.count {
            var trovato = false
            let massimo = Swift.min(lunghezzaMassima, parole.count - i)
            var lunghezza = massimo
            while lunghezza >= 1 {
                let sequenza = parole[i..<(i + lunghezza)].joined(separator: "_")
                if let voce = cerca(sequenza, distanzaMassima: distanzaMassima) {
                    if visti.insert(voce.voce.identificativo).inserted {
                        riconosciuti.append(Riconosciuto(
                            identificativo: voce.voce.identificativo,
                            nome: voce.voce.nome,
                            testoOriginale: parole[i..<(i + lunghezza)].joined(separator: " "),
                            tipo: voce.tipo))
                    }
                    i += lunghezza
                    trovato = true
                    break
                }
                lunghezza -= 1
            }
            if !trovato {
                let parola = parole[i]
                if !Self.parolePiene.contains(parola), parola.count >= 3, !parola.allSatisfy(\.isNumber) {
                    nonRiconosciute.append(parola)
                }
                i += 1
            }
        }
        return Esito(riconosciuti: riconosciuti, nonRiconosciuti: nonRiconosciute)
    }

    private func cerca(_ sequenza: String, distanzaMassima: Int)
        -> (voce: Voce, tipo: Riconosciuto.Tipo)? {
        if Self.parolePiene.contains(sequenza) { return nil }
        if let v = indice[sequenza] { return (v, .esatta) }
        for variante in Self.flessioni(sequenza) {
            if let v = indice[variante] { return (v, .esatta) }
        }
        // somiglianza: solo su parole abbastanza lunghe, altrimenti "riso" e
        // "viso" diventerebbero la stessa cosa
        guard sequenza.count >= 5, distanzaMassima > 0 else { return nil }
        let limite = sequenza.count >= 8 ? distanzaMassima : 1
        var migliore: (Voce, Int)?
        for (chiave, voce) in indice where abs(chiave.count - sequenza.count) <= limite {
            let d = Self.distanza(chiave, sequenza, limite: limite)
            if d <= limite, migliore == nil || d < migliore!.1 { migliore = (voce, d) }
            if d == 0 { break }
        }
        return migliore.map { ($0.0, .approssimata) }
    }

    /// Distanza di Levenshtein con uscita anticipata.
    static func distanza(_ a: String, _ b: String, limite: Int) -> Int {
        if a == b { return 0 }
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > limite { return limite + 1 }
        var precedente = Array(0...y.count)
        var corrente = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            corrente[0] = i
            var minimoRiga = corrente[0]
            for j in 1...y.count {
                let costo = x[i - 1] == y[j - 1] ? 0 : 1
                corrente[j] = Swift.min(precedente[j] + 1,
                                        corrente[j - 1] + 1,
                                        precedente[j - 1] + costo)
                minimoRiga = Swift.min(minimoRiga, corrente[j])
            }
            if minimoRiga > limite { return limite + 1 }
            swap(&precedente, &corrente)
        }
        return precedente[y.count]
    }

    func voce(perId id: String) -> Voce? { vociPerId[id] }
}
