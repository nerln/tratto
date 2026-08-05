import SwiftUI
import SwiftData

@main
struct TrattoApp: App {

    let contenitore: ModelContainer

    init() {
        let schema = Schema([
            Ingrediente.self, Pasto.self, VoceDiPasto.self,
            EventoIntestinale.self, EsitoGiornaliero.self,
            ContestoGiornaliero.self, Impostazioni.self,
        ])
        // Nessun CloudKit: i dati restano sul dispositivo e passano fra Mac e
        // telefono solo come file, quando lo decide l'utente.
        //
        // Il percorso è esplicito perché su Mac l'app non è in sandbox: senza
        // indicarlo, SwiftData scriverebbe un «default.store» direttamente
        // nella radice di Application Support, dove si scontrerebbe con
        // qualunque altra app fatta allo stesso modo.
        let configurazione: ModelConfiguration
        if let cartella = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("Tratto", isDirectory: true) {
            try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
            configurazione = ModelConfiguration(
                schema: schema,
                url: cartella.appendingPathComponent("tratto.store"),
                cloudKitDatabase: .none)
        } else {
            configurazione = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: false,
                                                cloudKitDatabase: .none)
        }
        do {
            contenitore = try ModelContainer(for: schema, configurations: [configurazione])
        } catch {
            fatalError("Impossibile aprire l'archivio: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContenutoView()
                .task { await Notifiche.configura() }
        }
        .modelContainer(contenitore)
        #if os(macOS)
        .defaultSize(width: 1000, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}

// MARK: - Radice

enum Scheda: String, CaseIterable, Identifiable, Hashable {
    case adesso, giornata, raccolta, archivio, esporta

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .adesso: "Adesso"
        case .giornata: "Giornata"
        case .raccolta: "Raccolta"
        case .archivio: "Archivio 2020"
        case .esporta: "Esporta"
        }
    }

    var simbolo: String {
        switch self {
        case .adesso: "plus.circle.fill"
        case .giornata: "list.bullet.rectangle"
        case .raccolta: "chart.bar.xaxis"
        case .archivio: "archivebox"
        case .esporta: "square.and.arrow.up"
        }
    }
}

struct ContenutoView: View {
    @Environment(\.modelContext) private var contesto
    @State private var scheda: Scheda = .adesso
    @State private var erroreAvvio: String?

    var body: some View {
        Gruppo
            .task { prepara() }
            .alert("Avvio non completato", isPresented: .constant(erroreAvvio != nil)) {
                Button("Va bene") { erroreAvvio = nil }
            } message: {
                Text(erroreAvvio ?? "")
            }
    }

    @ViewBuilder
    private var Gruppo: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Scheda.allCases, selection: $scheda) { s in
                Label(s.titolo, systemImage: s.simbolo).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            NavigationStack { vista(scheda) }
        }
        #else
        TabView(selection: $scheda) {
            ForEach(Scheda.allCases) { s in
                NavigationStack { vista(s) }
                    .tabItem { Label(s.titolo, systemImage: s.simbolo) }
                    .tag(s)
            }
        }
        #endif
    }

    @ViewBuilder
    private func vista(_ s: Scheda) -> some View {
        switch s {
        case .adesso: AdessoView()
        case .giornata: GiornataView()
        case .raccolta: RaccoltaView()
        case .archivio: ArchivioView()
        case .esporta: EsportaView()
        }
    }

    private func prepara() {
        do {
            try Avvio.preparaSeServe(contesto: contesto)
            #if DEBUG
            if let giorni = Anteprime.giorniRichiesti {
                try Anteprime.popola(contesto: contesto, giorni: giorni)
            }
            if let richiesta = Anteprime.schedaRichiesta { scheda = richiesta }
            #endif
        } catch { erroreAvvio = error.localizedDescription }
    }
}
