import Foundation

/// Test non parametrici esatti per confronti appaiati con pochissime coppie.
///
/// Sono esatti per enumerazione, non approssimati: con sei coppie qualunque
/// approssimazione normale è priva di senso, e il numero che decide tutto non è
/// la statistica scelta ma 2^n. Con k coppie il p bilaterale più piccolo
/// raggiungibile è 2^(1-k): con cinque coppie o meno nessun risultato può
/// essere significativo, qualunque cosa succeda. È una cosa da dire prima di
/// iniziare un confronto, non dopo.
///
/// La distribuzione nulla e' costruita per permutazione dei segni sui ranghi
/// EFFETTIVAMENTE osservati, non sulla tavola classica. Con gli ex aequo e con
/// la convenzione di Pratt le due cose non coincidono, e la tavola sbaglia:
/// verificato confrontando le due strade su casi con pareggi, dove scipy in
/// modalita' esatta usa la tavola e restituisce un valore diverso.
///
/// Oracolo dei test: enumerazione di tutti i 2^n assegnamenti di segno, fatta a
/// parte in Python. Sui casi senza pareggi ne' ex aequo coincide anche con
/// scipy, che li' e' esatto.
nonisolated enum TestEsatti {

    // MARK: - Convenzione sui pareggi

    /// Che cosa fare delle differenze esattamente nulle.
    ///
    /// Non è un dettaglio: su una scala ordinale a 7 livelli i pareggi saranno
    /// frequenti, e ogni pareggio scartato toglie una coppia. Sei coppie con
    /// due pareggi diventano quattro, e il p bilaterale minimo sale a 0,125:
    /// l'esperimento è morto prima di cominciare.
    enum Pareggi: String, CaseIterable, Sendable {
        /// Le differenze nulle si eliminano e n cala. È la convenzione classica.
        case escludi
        /// Le differenze nulle entrano nel calcolo dei ranghi e poi non
        /// contribuiscono alla statistica (Pratt 1959).
        case pratt
    }

    // MARK: - Test dei segni

    struct EsitoSegni: Sendable, Equatable {
        var positivi: Int
        var negativi: Int
        var pareggi: Int
        var coppieUsate: Int
        var pUnilaterale: Double
        var pBilaterale: Double
        /// Il p bilaterale più piccolo raggiungibile con le coppie rimaste.
        var pMinimoRaggiungibile: Double
    }

    /// Test dei segni esatto sulla distribuzione binomiale con p = 1/2.
    static func testDeiSegni(differenze: [Double]) -> EsitoSegni? {
        let positivi = differenze.filter { $0 > 0 }.count
        let negativi = differenze.filter { $0 < 0 }.count
        let pareggi = differenze.filter { $0 == 0 }.count
        let n = positivi + negativi
        guard n >= 1 else {
            // Tutte le differenze sono nulle. Non e' un errore ed e' anzi il
            // caso che va detto per intero: il confronto e' finito senza
            // nessuna coppia utilizzabile.
            return EsitoSegni(positivi: 0, negativi: 0, pareggi: pareggi, coppieUsate: 0,
                              pUnilaterale: 1, pBilaterale: 1, pMinimoRaggiungibile: 1)
        }

        // coda dalla parte osservata
        let k = Swift.min(positivi, negativi)
        let coda = (0...k).reduce(0.0) { $0 + binomiale(n, $1) } / pow(2, Double(n))
        let unilaterale = positivi >= negativi
            ? (k...n).reduce(0.0) { $0 + binomiale(n, $1) } / pow(2, Double(n))
            : coda
        let bilaterale = Swift.min(1, 2 * coda)

        return EsitoSegni(positivi: positivi, negativi: negativi, pareggi: pareggi,
                          coppieUsate: n,
                          pUnilaterale: positivi > negativi ? coda : unilaterale,
                          pBilaterale: bilaterale,
                          pMinimoRaggiungibile: Swift.min(1, pow(2, 1 - Double(n))))
    }

    static func binomiale(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        var r = 1.0
        for i in 0..<Swift.min(k, n - k) {
            r = r * Double(n - i) / Double(i + 1)
        }
        return r.rounded()
    }

    // MARK: - Wilcoxon dei ranghi con segno

    struct EsitoWilcoxon: Sendable, Equatable {
        var wPositivo: Double
        var wNegativo: Double
        var coppieUsate: Int
        var pareggi: Int
        var convenzione: Pareggi
        /// `true` quando i ranghi contengono ex aequo e la distribuzione nulla
        /// è stata costruita per permutazione dei segni sui ranghi osservati
        /// invece che sulla tavola senza pareggi.
        var ranghiConExAequo: Bool
        var pUnilaterale: Double
        var pBilaterale: Double
        var pMinimoRaggiungibile: Double
        /// Stimatore di Hodges-Lehmann: la mediana delle medie di Walsh.
        var stimaHodgesLehmann: Double?
        /// Estremi dell'intervallo, con il livello di confidenza EFFETTIVO.
        /// Con sei coppie non esiste un intervallo al 95%: esistono il 96,875%
        /// e il 93,75%. Mostrarne uno chiamandolo 95% sarebbe una bugia su un
        /// numero che chi legge prende per esatto.
        var intervallo: (basso: Double, alto: Double, confidenza: Double)?

        static func == (a: EsitoWilcoxon, b: EsitoWilcoxon) -> Bool {
            a.wPositivo == b.wPositivo && a.wNegativo == b.wNegativo
            && a.coppieUsate == b.coppieUsate && a.pareggi == b.pareggi
            && a.convenzione == b.convenzione && a.pUnilaterale == b.pUnilaterale
            && a.pBilaterale == b.pBilaterale
        }
    }

    static func wilcoxon(differenze: [Double], pareggi convenzione: Pareggi = .pratt) -> EsitoWilcoxon? {
        let nPareggi = differenze.filter { $0 == 0 }.count
        let usate: [Double] = convenzione == .escludi
            ? differenze.filter { $0 != 0 }
            : differenze
        guard !usate.isEmpty else { return nil }

        // ranghi dei valori assoluti, con media dei ranghi in caso di ex aequo
        let ranghi = ranghiMedi(usate.map(abs))
        let conExAequo = Set(usate.map(abs)).count != usate.count

        var wPos = 0.0, wNeg = 0.0
        for (i, d) in usate.enumerated() {
            if d > 0 { wPos += ranghi[i] } else if d < 0 { wNeg += ranghi[i] }
        }

        // Sotto Pratt le differenze nulle ricevono i ranghi più bassi e restano
        // sempre fuori dalla statistica, ma i loro ranghi non sono disponibili
        // per le altre: è questo che rende la distribuzione diversa.
        let ranghiAttivi: [Double] = zip(usate, ranghi).compactMap { $0.0 == 0 ? nil : $0.1 }
        let n = ranghiAttivi.count
        guard n >= 1 else { return nil }

        let distribuzione = distribuzioneNulla(ranghiAttivi)
        let totale = pow(2, Double(n))
        let osservata = Swift.min(wPos, wNeg)

        let coda = distribuzione.filter { $0.key <= osservata + 1e-9 }
            .reduce(0.0) { $0 + $1.value } / totale
        let bilaterale = Swift.min(1, 2 * coda)
        let unilaterale = wPos >= wNeg
            ? distribuzione.filter { $0.key >= wPos - 1e-9 }.reduce(0.0) { $0 + $1.value } / totale
            : coda

        let walsh = mediaDiWalsh(usate.filter { convenzione == .escludi ? $0 != 0 : true })
        let hl = mediana(walsh)
        let intervallo = intervalloHodgesLehmann(walsh, distribuzione: distribuzione, n: n)

        return EsitoWilcoxon(
            wPositivo: wPos, wNegativo: wNeg, coppieUsate: n, pareggi: nPareggi,
            convenzione: convenzione, ranghiConExAequo: conExAequo,
            pUnilaterale: unilaterale, pBilaterale: bilaterale,
            pMinimoRaggiungibile: Swift.min(1, pow(2, 1 - Double(n))),
            stimaHodgesLehmann: hl, intervallo: intervallo)
    }

    /// Distribuzione nulla di W esatta, per enumerazione dei 2^n segni.
    /// Costruita sui ranghi effettivamente osservati, così vale anche con gli
    /// ex aequo e con la convenzione di Pratt, dove la tavola classica sbaglia.
    static func distribuzioneNulla(_ ranghi: [Double]) -> [Double: Double] {
        var d: [Double: Double] = [0: 1]
        for r in ranghi {
            var nuova: [Double] = []
            var conteggi: [Double: Double] = [:]
            for (somma, peso) in d {
                for candidato in [somma, somma + r] {
                    let chiave = (candidato * 2).rounded() / 2   // ranghi medi: multipli di 0,5
                    conteggi[chiave, default: 0] += peso
                    nuova.append(chiave)
                }
            }
            d = conteggi
        }
        return d
    }

    static func ranghiMedi(_ valori: [Double]) -> [Double] {
        let ordinati = valori.enumerated().sorted { $0.element < $1.element }
        var ranghi = [Double](repeating: 0, count: valori.count)
        var i = 0
        while i < ordinati.count {
            var j = i
            while j + 1 < ordinati.count, ordinati[j + 1].element == ordinati[i].element { j += 1 }
            let medio = Double((i + 1) + (j + 1)) / 2
            for k in i...j { ranghi[ordinati[k].offset] = medio }
            i = j + 1
        }
        return ranghi
    }

    static func mediaDiWalsh(_ x: [Double]) -> [Double] {
        var w: [Double] = []
        for i in x.indices {
            for j in i..<x.count { w.append((x[i] + x[j]) / 2) }
        }
        return w.sorted()
    }

    static func mediana(_ x: [Double]) -> Double? {
        guard !x.isEmpty else { return nil }
        let s = x.sorted()
        let m = s.count / 2
        return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
    }

    /// Intervallo di confidenza per la mediana delle differenze, con il livello
    /// effettivo raggiungibile: a sei coppie non è mai il 95%.
    static func intervalloHodgesLehmann(_ walsh: [Double],
                                        distribuzione: [Double: Double],
                                        n: Int,
                                        obiettivo: Double = 0.95)
        -> (basso: Double, alto: Double, confidenza: Double)? {
        guard walsh.count >= 2, n >= 2 else { return nil }
        let totale = pow(2, Double(n))
        // il più grande k tale che P(W <= k-1) * 2 <= 1 - obiettivo
        let valori = distribuzione.keys.sorted()
        var cumulata = 0.0
        var kScelto = -1
        var confidenza = 1.0
        for v in valori {
            let successiva = cumulata + (distribuzione[v] ?? 0)
            if 2 * (successiva / totale) > 1 - obiettivo { break }
            cumulata = successiva
            kScelto = Int(v.rounded())
            confidenza = 1 - 2 * (cumulata / totale)
        }
        guard kScelto >= 0 else { return nil }
        let indice = kScelto                     // conteggio di medie di Walsh da scartare per lato
        guard indice < walsh.count - indice else { return nil }
        return (walsh[indice], walsh[walsh.count - 1 - indice], confidenza)
    }

    // MARK: - Potenza

    /// Potenza di un confronto appaiato che richiede l'unanimità.
    ///
    /// È il numero che va mostrato PRIMA di iniziare, e quasi sempre è
    /// deprimente: con sei blocchi e test bilaterale servono sei concordanze su
    /// sei, quindi la potenza è semplicemente p^6. Anche con un alimento che
    /// peggiora davvero i sintomi in otto blocchi su dieci, la probabilità di
    /// arrivare a un risultato significativo è circa il 26%.
    static func potenzaTestDeiSegni(blocchi: Int, probabilitaConcordanza p: Double,
                                    alfa: Double = 0.05, unilaterale: Bool = false) -> Double? {
        guard blocchi >= 1, p > 0, p <= 1 else { return nil }
        // quante concordanze servono perché il p esatto stia sotto alfa
        var soglia: Int?
        for k in stride(from: blocchi, through: (blocchi / 2) + 1, by: -1) {
            let coda = (k...blocchi).reduce(0.0) { $0 + binomiale(blocchi, $1) } / pow(2, Double(blocchi))
            let valore = unilaterale ? coda : Swift.min(1, 2 * coda)
            if valore <= alfa { soglia = k } else { break }
        }
        guard let necessarie = soglia else { return 0 }
        // P(almeno `necessarie` successi) con probabilità p
        var potenza = 0.0
        for k in necessarie...blocchi {
            potenza += binomiale(blocchi, k) * pow(p, Double(k)) * pow(1 - p, Double(blocchi - k))
        }
        return potenza
    }

    /// Il numero minimo di blocchi che rende raggiungibile la significatività.
    static func blocchiMinimi(alfa: Double = 0.05, unilaterale: Bool = false) -> Int {
        for n in 1...40 {
            let coda = 1 / pow(2, Double(n))
            let valore = unilaterale ? coda : 2 * coda
            if valore <= alfa { return n }
        }
        return 40
    }
}
