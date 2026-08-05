import Foundation
import UserNotifications

/// I tre promemoria della giornata, e soprattutto il tasto «Niente».
///
/// È il pezzo che risponde al difetto peggiore del diario del 2020: le fasce
/// saltate non venivano recuperate dalla buona volontà. Una notifica con
/// un'azione diretta trasforma una fascia mancante in un dato senza nemmeno
/// aprire l'app, ed è l'unica soluzione al fatto che una colazione uguale a
/// tutte le altre non si ricorda.
enum Notifiche {

    static let categoriaPasto = "TRATTO_PASTO"
    static let categoriaSera = "TRATTO_SERA"
    static let azioneNiente = "TRATTO_NIENTE"
    static let azioneApri = "TRATTO_APRI"

    static let orari: [(identificativo: String, ora: Int, minuto: Int, fascia: Fascia, testo: String)] = [
        ("mattina", 10, 30, .colazione, "Hai fatto colazione?"),
        ("pomeriggio", 15, 0, .pranzo, "Hai pranzato?"),
    ]

    static func configura() async {
        let centro = UNUserNotificationCenter.current()

        let niente = UNNotificationAction(identifier: azioneNiente, title: "Niente", options: [])
        let apri = UNNotificationAction(identifier: azioneApri, title: "Registra",
                                        options: [.foreground])
        centro.setNotificationCategories([
            UNNotificationCategory(identifier: categoriaPasto,
                                   actions: [niente, apri], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: categoriaSera,
                                   actions: [apri], intentIdentifiers: [], options: []),
        ])
    }

    static func chiediPermesso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func programma(oraSera: Int) async {
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()

        for o in orari {
            let contenuto = UNMutableNotificationContent()
            contenuto.title = "Tratto"
            contenuto.body = o.testo
            contenuto.categoryIdentifier = categoriaPasto
            contenuto.userInfo = ["fascia": o.fascia.rawValue]
            var quando = DateComponents()
            quando.hour = o.ora
            quando.minute = o.minuto
            let richiesta = UNNotificationRequest(
                identifier: "pasto-\(o.identificativo)",
                content: contenuto,
                trigger: UNCalendarNotificationTrigger(dateMatching: quando, repeats: true))
            try? await centro.add(richiesta)
        }

        let sera = UNMutableNotificationContent()
        sera.title = "Tratto"
        sera.body = "Quanto ti ha fatto male la pancia oggi, da 0 a 10?"
        sera.categoryIdentifier = categoriaSera
        var quandoSera = DateComponents()
        quandoSera.hour = oraSera
        quandoSera.minute = 0
        try? await centro.add(UNNotificationRequest(
            identifier: "sera",
            content: sera,
            trigger: UNCalendarNotificationTrigger(dateMatching: quandoSera, repeats: true)))
    }

    static func annulla() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
