import Foundation

/// Statistica descrittiva. Deliberatamente priva di test di ipotesi.
///
/// Non c'e' nessun p-value qui dentro, e nessuna funzione che metta in
/// relazione un alimento con un esito. Non e' una dimenticanza: e' il confine
/// dell'app. Cio' che questo file calcola serve a rispondere a una domanda
/// sola, che nel 2020 non era stata posta: *quanto rumore c'e'*, e quindi
/// quale effetto sarebbe grande abbastanza da poter essere visto.
nonisolated enum Statistica {

    // MARK: - Descrittive di base

    static func media(_ x: [Double]) -> Double? {
        x.isEmpty ? nil : x.reduce(0, +) / Double(x.count)
    }

    static func mediana(_ x: [Double]) -> Double? {
        guard !x.isEmpty else { return nil }
        let s = x.sorted()
        let m = s.count / 2
        return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
    }

    /// Deviazione standard campionaria (denominatore n-1).
    static func deviazioneStandard(_ x: [Double]) -> Double? {
        guard x.count >= 2, let m = media(x) else { return nil }
        let ss = x.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (ss / Double(x.count - 1)).squareRoot()
    }

    static func percentile(_ x: [Double], _ p: Double) -> Double? {
        guard !x.isEmpty else { return nil }
        let s = x.sorted()
        if s.count == 1 { return s[0] }
        let pos = p * Double(s.count - 1)
        let lo = Int(pos.rounded(.down))
        let hi = Swift.min(lo + 1, s.count - 1)
        let f = pos - Double(lo)
        return s[lo] * (1 - f) + s[hi] * f
    }

    /// Entropia normalizzata di una variabile ordinale: 1 = i livelli sono
    /// usati in modo uniforme, 0 = e' sempre lo stesso valore.
    /// Una variabile schiacciata su pochi livelli non ha spazio per mostrare
    /// un effetto, qualunque disegno si usi.
    static func entropiaNormalizzata(_ x: [Int]) -> Double? {
        guard !x.isEmpty else { return nil }
        var conteggi: [Int: Int] = [:]
        for v in x { conteggi[v, default: 0] += 1 }
        guard conteggi.count > 1 else { return 0 }
        let n = Double(x.count)
        let h = conteggi.values.reduce(0.0) { acc, k in
            let p = Double(k) / n
            return acc - p * log2(p)
        }
        return h / log2(Double(conteggi.count))
    }

    // MARK: - Scomposizione della varianza

    struct ComponentiVarianza: Sendable, Equatable {
        /// Varianza fra le osservazioni dello stesso giorno.
        var entroGiorno: Double
        /// Varianza fra giorni diversi.
        var fraGiorni: Double
        /// Quota della varianza attribuibile al giorno (ICC a effetti casuali,
        /// modello a una via). Vicino a 0 significa che due evacuazioni dello
        /// stesso giorno differiscono quanto due giorni diversi: in quel caso
        /// una media giornaliera e' quasi solo rumore.
        var icc: Double
        var osservazioni: Int
        var giorni: Int
        var mediaOsservazioniPerGiorno: Double
    }

    /// ANOVA a una via a effetti casuali su gruppi di dimensione diversa.
    static func componentiVarianza(gruppi: [[Double]]) -> ComponentiVarianza? {
        let g = gruppi.filter { !$0.isEmpty }
        let k = g.count
        let n = g.reduce(0) { $0 + $1.count }
        guard k >= 2, n > k else { return nil }

        let totale = g.reduce(0.0) { $0 + $1.reduce(0, +) }
        let generale = totale / Double(n)

        var ssFra = 0.0, ssEntro = 0.0
        for gruppo in g {
            let m = gruppo.reduce(0, +) / Double(gruppo.count)
            ssFra += Double(gruppo.count) * (m - generale) * (m - generale)
            ssEntro += gruppo.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        }
        let msFra = ssFra / Double(k - 1)
        let msEntro = ssEntro / Double(n - k)

        // dimensione di gruppo efficace per gruppi sbilanciati
        let sommaQuadrati = g.reduce(0.0) { $0 + Double($1.count * $1.count) }
        let n0 = (Double(n) - sommaQuadrati / Double(n)) / Double(k - 1)
        guard n0 > 0 else { return nil }

        let varFra = Swift.max(0, (msFra - msEntro) / n0)
        let denom = varFra + msEntro
        let icc = denom > 0 ? varFra / denom : 0

        return ComponentiVarianza(
            entroGiorno: msEntro, fraGiorni: varFra, icc: icc,
            osservazioni: n, giorni: k,
            mediaOsservazioniPerGiorno: Double(n) / Double(k))
    }

    // MARK: - Autocorrelazione

    struct Autocorrelazione: Sendable, Equatable {
        var ritardo: Int
        var r: Double?
        var coppie: Int
    }

    /// Correlazione della serie con se' stessa a distanza di `ritardo` giorni.
    ///
    /// Serve a una decisione concreta: quanto deve durare una pausa fra due
    /// condizioni perche' la seconda non porti dentro l'eco della prima.
    /// Se i giorni consecutivi sono correlati, trattarli come indipendenti
    /// gonfia i falsi positivi.
    ///
    /// `serie` e' indicizzata per giorno; i giorni mancanti sono buchi veri e
    /// le coppie che li toccano vengono scartate invece di essere interpolate.
    static func autocorrelazione(serie: [Date: Double],
                                 ritardiMassimi: Int = 7,
                                 coppieMinime: Int = 8,
                                 calendario: Calendar = .current) -> [Autocorrelazione] {
        guard let inizio = serie.keys.min(), let fine = serie.keys.max() else { return [] }
        var griglia: [Double?] = []
        var giorno = calendario.startOfDay(for: inizio)
        let ultimo = calendario.startOfDay(for: fine)
        while giorno <= ultimo {
            griglia.append(serie[giorno])
            guard let prossimo = calendario.date(byAdding: .day, value: 1, to: giorno) else { break }
            giorno = prossimo
        }

        return (1...Swift.max(1, ritardiMassimi)).map { ritardo in
            var xs: [Double] = [], ys: [Double] = []
            for i in 0..<Swift.max(0, griglia.count - ritardo) {
                if let a = griglia[i], let b = griglia[i + ritardo] { xs.append(a); ys.append(b) }
            }
            guard xs.count >= coppieMinime else {
                return Autocorrelazione(ritardo: ritardo, r: nil, coppie: xs.count)
            }
            return Autocorrelazione(ritardo: ritardo, r: pearson(xs, ys), coppie: xs.count)
        }
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 3,
              let mx = media(x), let my = media(y) else { return nil }
        var num = 0.0, sx = 0.0, sy = 0.0
        for i in x.indices {
            let a = x[i] - mx, b = y[i] - my
            num += a * b; sx += a * a; sy += b * b
        }
        let den = (sx * sy).squareRoot()
        return den > 0 ? num / den : nil
    }

    /// La pausa piu' corta dopo la quale la serie non ricorda piu' se stessa
    /// in modo apprezzabile. Il valore restituito e' un numero di giorni
    /// derivato dai dati, non una costante scelta a tavolino.
    static func pausaSuggerita(_ acf: [Autocorrelazione], soglia: Double = 0.2) -> Int? {
        for a in acf.sorted(by: { $0.ritardo < $1.ritardo }) {
            guard let r = a.r else { continue }
            if abs(r) < soglia { return a.ritardo }
        }
        return nil
    }

    // MARK: - Differenza minima rilevabile

    /// Quantili t bilaterali al 97,5% per gradi di liberta' bassi. Oltre 30 la
    /// differenza dal valore normale (1,96) e' trascurabile per questo uso.
    private static let tCritici: [Double] = [
        12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
        2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
        2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042,
    ]

    private static func tCritico(gradiLiberta: Int) -> Double {
        guard gradiLiberta >= 1 else { return 12.706 }
        return gradiLiberta <= tCritici.count ? tCritici[gradiLiberta - 1] : 1.96
    }

    struct StimaRilevabilita: Sendable, Equatable {
        var periodi: Int
        var giorniPerPeriodo: Int
        var giorniTotali: Int
        /// La differenza piu' piccola, nelle unita' della scala, che avrebbe
        /// l'80% di probabilita' di essere vista.
        var differenzaMinima: Double
    }

    /// Differenza minima rilevabile in un confronto appaiato a `periodi` coppie.
    ///
    /// Assume che i periodi siano indipendenti fra loro: e' il caso migliore.
    /// L'autocorrelazione misurata dice quanto quell'assunzione sia vera, ed e'
    /// il motivo per cui la pausa fra i periodi va derivata e non decisa.
    static func differenzaMinimaRilevabile(sdGiornaliera: Double,
                                           periodi: Int,
                                           giorniPerPeriodo: Int,
                                           potenza: Double = 0.80) -> StimaRilevabilita? {
        guard sdGiornaliera > 0, periodi >= 2, giorniPerPeriodo >= 1 else { return nil }
        let sdPeriodo = sdGiornaliera / Double(giorniPerPeriodo).squareRoot()
        let sdDifferenza = sdPeriodo * 2.0.squareRoot()
        let zPotenza = quantileNormale(potenza)
        let t = tCritico(gradiLiberta: periodi - 1)
        let delta = (t + zPotenza) * sdDifferenza / Double(periodi).squareRoot()
        return StimaRilevabilita(periodi: periodi,
                                 giorniPerPeriodo: giorniPerPeriodo,
                                 giorniTotali: periodi * giorniPerPeriodo * 2,
                                 differenzaMinima: delta)
    }

    /// Inversa della normale standard, approssimazione di Acklam.
    static func quantileNormale(_ p: Double) -> Double {
        guard p > 0, p < 1 else { return 0 }
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                 3.754408661907416e+00]
        let pBasso = 0.02425, pAlto = 1 - pBasso
        if p < pBasso {
            let q = (-2 * log(p)).squareRoot()
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                 / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        if p > pAlto {
            let q = (-2 * log(1 - p)).squareRoot()
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                  / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        let q = p - 0.5, r = q * q
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
             / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    }
}
