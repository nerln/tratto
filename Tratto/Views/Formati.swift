import Foundation

/// Formattazione dei numeri dentro le frasi.
///
/// Non è pignoleria: l'app scrive frasi in italiano e le mette anche dentro un
/// documento destinato a un medico. Un «4.0» con il punto e un «distanti 1
/// giorni» fanno sembrare improvvisato un referto che invece è l'unica cosa
/// che verrà letta da qualcun altro.
nonisolated enum Formati {

    static let italiano = Locale(identifier: "it_IT")

    /// Un decimale, con la virgola.
    static func decimale(_ x: Double, cifre: Int = 1) -> String {
        x.formatted(.number.precision(.fractionLength(cifre)).locale(italiano))
    }

    static func percentuale(_ x: Double) -> String {
        "\(Int((x * 100).rounded()))%"
    }

    /// «lo 0%» ma «il 57%»: in italiano l'articolo cambia davanti a "zero".
    static func percentualeConArticolo(_ x: Double) -> String {
        let p = Int((x * 100).rounded())
        return p == 0 ? "lo 0%" : "il \(p)%"
    }

    static func plurale(_ n: Int, _ singolare: String, _ plurale: String) -> String {
        "\(n) \(n == 1 ? singolare : plurale)"
    }

    static func giorni(_ n: Int) -> String { plurale(n, "giorno", "giorni") }
}
