import Testing
import Foundation
import SwiftUI
@testable import Tratto

/// Un buco di traduzione non fa fallire niente: fa comparire una parola
/// inglese in mezzo all'italiano, mesi dopo, e nessuno se ne accorge. Queste
/// prove leggono i file COMPILATI dentro il bundle, non il catalogo sorgente,
/// perché è la compilazione a decidere che cosa finisce dove.
@Suite("Localizzazione")
struct LocalizzazioneTests {

    private final class Ancora {}
    private static var bundleApp: Bundle { Bundle(for: Ancora.self) }

    private static func bundle(_ codice: String) -> Bundle? {
        bundleApp.url(forResource: codice, withExtension: "lproj").flatMap(Bundle.init(url:))
            ?? Bundle.main.url(forResource: codice, withExtension: "lproj").flatMap(Bundle.init(url:))
    }

    private static func stringhe(_ codice: String) -> [String: String]? {
        guard let b = bundle(codice),
              let url = b.url(forResource: "Localizable", withExtension: "strings"),
              let d = try? Data(contentsOf: url),
              let p = try? PropertyListSerialization.propertyList(from: d, format: nil)
        else { return nil }
        return p as? [String: String]
    }

    @Test("l'app contiene entrambe le lingue")
    func lingueNelBundle() throws {
        let localizzazioni = Set(Self.bundleApp.localizations).union(Bundle.main.localizations)
        #expect(localizzazioni.contains("en"), "manca l'inglese: \(localizzazioni.sorted())")
        #expect(localizzazioni.contains("it"), "manca l'italiano: \(localizzazioni.sorted())")
    }

    @Test("ogni chiave inglese ha una traduzione italiana non vuota")
    func nessunBuco() throws {
        let en = try #require(Self.stringhe("en"), "en.lproj/Localizable.strings non trovato")
        let it = try #require(Self.stringhe("it"), "it.lproj/Localizable.strings non trovato")
        #expect(en.count > 200, "solo \(en.count) chiavi: l'estrazione non ha funzionato")

        let mancanti = en.keys.filter { (it[$0] ?? "").isEmpty }.sorted()
        #expect(mancanti.isEmpty, "senza traduzione: \(mancanti.prefix(10))")
    }

    @Test("nessuna traduzione italiana è rimasta identica all'inglese per sbaglio")
    func nienteInglesePassatoPerItaliano() throws {
        let en = try #require(Self.stringhe("en"))
        let it = try #require(Self.stringhe("it"))
        // le voci che possono legittimamente coincidere
        let ammesse: Set<String> = ["Tratto", "FHIR", "JSON", "Stress", "%lld", "%@ – %@"]
        let identiche = en.keys.filter { chiave in
            guard let valoreIt = it[chiave], let valoreEn = en[chiave] else { return false }
            guard valoreIt == valoreEn, valoreEn.count > 4 else { return false }
            return !ammesse.contains(chiave) && !valoreEn.allSatisfy { !$0.isLetter }
        }.sorted()
        #expect(identiche.isEmpty, "non tradotte: \(identiche.prefix(10))")
    }

    @Test("i segnaposto sopravvivono alla traduzione, in numero e ordine")
    func segnapostoIntatti() throws {
        let en = try #require(Self.stringhe("en"))
        let it = try #require(Self.stringhe("it"))
        let schema = try Regex(#"%(?:\d+\$)?(?:lld|ld|@|lf|f|d)"#)
        var rotte: [String] = []
        for (chiave, valoreEn) in en {
            guard let valoreIt = it[chiave] else { continue }
            let a = valoreEn.matches(of: schema).map { String(valoreEn[$0.range]) }
            let b = valoreIt.matches(of: schema).map { String(valoreIt[$0.range]) }
            if a != b { rotte.append("\(chiave): \(a) -> \(b)") }
        }
        #expect(rotte.isEmpty, "segnaposto alterati: \(rotte.prefix(5))")
    }

    @Test("le stringhe italiane non usano il trattino lungo come punteggiatura")
    func nienteTrattinoLungo() throws {
        let it = try #require(Self.stringhe("it"))
        let colpevoli = it.filter { $0.value.contains(" — ") }.map(\.key).sorted()
        #expect(colpevoli.isEmpty, "trattino lungo in: \(colpevoli.prefix(5))")
    }

    @Test("la risoluzione fuori dalle viste segue la lingua richiesta")
    func risoluzioneEsplicita() {
        // È il secondo binario: l'ambiente di SwiftUI non arriva al referto né
        // all'export, e `String(localized:locale:)` non cambia lingua.
        // `LocalizedStringResource(_, locale:)` invece sì, ed è quello che
        // usa `testo(_:_:)`.
        let en = testo("Bathroom", Locale(identifier: "en"))
        let it = testo("Bathroom", Locale(identifier: "it"))
        #expect(en == "Bathroom")
        #expect(it == "Bagno")
    }

    @Test("le etichette dei modelli cambiano lingua")
    func modelliLocalizzati() {
        let en = Locale(identifier: "en"), it = Locale(identifier: "it")
        #expect(FormaFecale.liquida.etichetta(en) == "Liquid")
        #expect(FormaFecale.liquida.etichetta(it) == "Liquida")
        #expect(Fascia.colazione.nome(en) == "Breakfast")
        #expect(Fascia.colazione.nome(it) == "Colazione")
        #expect(StatoPasto.digiuno.nome(en) == "Nothing")
        #expect(StatoPasto.digiuno.nome(it) == "Niente")
    }

    @Test("le tre scelte di lingua si comportano come dichiarato")
    func sceltaLingua() {
        #expect(Lingua.sistema.locale == nil)
        #expect(Lingua.inglese.locale?.identifier == "en")
        #expect(Lingua.italiano.locale?.identifier == "it")
        // i nomi delle lingue si scrivono nella lingua stessa
        #expect(Lingua.italiano.nomeNativo == "Italiano")
        #expect(Lingua.inglese.nomeNativo == "English")
    }

    @Test("l'export strutturato resta in inglese anche con l'app in italiano")
    func exportSempreInglese() {
        // Il referto lo legge una persona e segue la lingua scelta; il bundle
        // FHIR e il JSON li legge una macchina o un clinico che potrebbe non
        // parlare la lingua di chi li ha prodotti.
        let c = Concetto.formaFecale.codificaLocale
        #expect(c.etichetta == "Stool form (local 1-7 scale)")
        #expect(Concetto.dolorePeggiore24h.codificaLocale.etichetta
                == "Worst abdominal pain in the last 24 hours (0-10)")
    }

    @Test("i 142 ingredienti hanno un nome in entrambe le lingue")
    func ingredientiBilingui() throws {
        let seed = try #require(SeedOntologia.daBundle(Self.bundleApp)
                                ?? SeedOntologia.daBundle(.main))
        for v in seed.ingredienti {
            #expect(!v.nomeIt.isEmpty && !v.nomeEn.isEmpty, "voce incompleta: \(v.id)")
            #expect(!v.categoriaIt.isEmpty && !v.categoriaEn.isEmpty, "categoria mancante: \(v.id)")
        }
        // un campione di traduzioni che devono essere giuste
        func nome(_ id: String, _ lingua: String) -> String? {
            seed.ingredienti.first { $0.id == id }
                .map { lingua == "it" ? $0.nomeIt : $0.nomeEn }
        }
        #expect(nome("mela", "en") == "Apple")
        #expect(nome("mela", "it") == "Mela")
        #expect(nome("olio_di_oliva", "en") == "Olive oil")
        #expect(nome("zucchina", "en") == "Courgette")
    }
}
