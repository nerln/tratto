import SwiftUI
import SwiftData

/// Il pasto si scrive o si detta in linguaggio naturale, e viene mostrato come
/// una fila di etichette modificabili.
///
/// Il testo grezzo si salva sempre, anche quando non si riconosce niente:
/// meglio una riga di diario da sistemare dopo che una fascia vuota per
/// sempre. Le proposte del modello passano tutte dal vocabolario e nessuna
/// entra senza conferma.
struct RegistraPastoView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi
    @Environment(\.locale) private var locale

    var testoIniziale: String = ""
    var pastoDaModificare: Pasto?

    @Query(sort: \Ingrediente.nomeEn) private var ingredienti: [Ingrediente]

    @State private var testo = ""
    @State private var quando: Date = .now
    @State private var fascia: Fascia = Fascia.dedotta(da: .now)
    @State private var scelti: [Corrispondenza.Riconosciuto] = []
    @State private var candidati: [String] = []
    @State private var quantita: [String: Quantita] = [:]
    @State private var inAnalisi = false
    @State private var modelloUsato = false
    @State private var mostraCatalogo = false
    @State private var correggiOra = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    campoTesto
                    if inAnalisi { ProgressView().frame(maxWidth: .infinity) }
                    if !scelti.isEmpty { etichette }
                    if !candidati.isEmpty { nuoviIngredienti }
                    dettagli
                    if let motivo = AnalizzatorePasto.motivoIndisponibilita { notaModello(motivo) }
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(pastoDaModificare == nil ? "Meal" : "Edit meal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { salva() }
                        .disabled(scelti.isEmpty && testo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $mostraCatalogo) {
                CatalogoIngredientiView(giaScelti: Set(scelti.map(\.identificativo))) { voce in
                    aggiungi(identificativo: voce.identificativo, nome: voce.nome(locale), testo: voce.nome(locale))
                }
            }
            .task { await preparaIniziale() }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 560)
        #endif
    }

    // MARK: - Pezzi

    private var campoTesto: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What did you eat?", text: $testo, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(2...5)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.10)))
                .onSubmit { Task { await analizza() } }
            HStack {
                Button {
                    Task { await analizza() }
                } label: {
                    Label("Recognise", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(testo.trimmingCharacters(in: .whitespaces).isEmpty || inAnalisi)

                Button {
                    mostraCatalogo = true
                } label: {
                    Label("From catalogue", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
    }

    private var etichette: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients").font(.subheadline.weight(.semibold))
            FlussoEtichette(scelti) { r in
                Menu {
                    ForEach(Quantita.allCases, id: \.self) { q in
                        Button(String(localized: .init(q.chiaveNome), locale: locale)) { quantita[r.identificativo] = q }
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        scelti.removeAll { $0.identificativo == r.identificativo }
                        quantita[r.identificativo] = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(r.nome).font(.callout)
                        if let q = quantita[r.identificativo], q != .normale {
                            Text(q.nome(locale).lowercased()).font(.caption2).foregroundStyle(.secondary)
                        }
                        if r.tipo == .approssimata {
                            Image(systemName: "questionmark.circle").font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            if scelti.contains(where: { $0.tipo == .approssimata }) {
                Text("The question mark marks entries matched by similarity: check them.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var nuoviIngredienti: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not in the catalogue").font(.subheadline.weight(.semibold))
            FlussoEtichette(candidati.map { IdentificabileTesto(testo: $0) }) { c in
                Button {
                    creaIngrediente(c.testo)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill").font(.caption)
                        Text(c.testo).font(.callout)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Capsule().fill(Color.gray.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
            Text("Tap to add them to your catalogue. Whatever you skip still stays in the text of the meal.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var dettagli: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Meal slot", selection: $fascia) {
                ForEach(Fascia.allCases) { f in Text(LocalizedStringKey(f.chiaveNome)).tag(f) }
            }
            .pickerStyle(.menu)

            DisclosureGroup(isExpanded: $correggiOra) {
                DatePicker("Time", selection: $quando).labelsHidden().datePickerStyle(.compact)
            } label: {
                HStack {
                    Text("Time")
                    Spacer()
                    Text(quando.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private func notaModello(_ motivo: String) -> some View {
        Text("\(motivo) Recognition still works by matching your text against the catalogue.")
            .font(.caption2).foregroundStyle(.secondary)
    }

    // MARK: - Logica

    private func costruisciCorrispondenza() -> Corrispondenza {
        // Le voci piu' specifiche per prime, cosi' "pasta integrale" vince su "pasta".
        let voci = ingredienti
            .filter { !$0.archiviato }
            .map { Corrispondenza.Voce(identificativo: $0.identificativo,
                                       nome: $0.nome(locale),
                                       forme: $0.formeRiconoscibili) }
            .sorted { a, b in
                let la = a.forme.map(\.count).max() ?? 0
                let lb = b.forme.map(\.count).max() ?? 0
                return la > lb
            }
        return Corrispondenza(voci: voci)
    }

    private func preparaIniziale() async {
        if let p = pastoDaModificare {
            testo = p.testoGrezzo
            quando = p.quando
            fascia = p.fascia
            scelti = p.vociOrdinate.compactMap { v in
                guard let i = v.ingrediente else { return nil }
                quantita[i.identificativo] = v.quantita
                return Corrispondenza.Riconosciuto(identificativo: i.identificativo, nome: i.nome(locale),
                                                   testoOriginale: v.testoOriginale, tipo: .esatta)
            }
        } else if !testoIniziale.isEmpty {
            testo = testoIniziale
            await analizza()
        }
    }

    private func analizza() async {
        let da = testo
        guard !da.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        inAnalisi = true
        defer { inAnalisi = false }
        let analizzatore = AnalizzatorePasto(corrispondenza: costruisciCorrispondenza())
        let esito = await analizzatore.analizza(da)
        var uniti = scelti
        for r in esito.riconosciuti where !uniti.contains(where: { $0.identificativo == r.identificativo }) {
            uniti.append(r)
        }
        scelti = uniti
        candidati = esito.candidatiNuovi
        modelloUsato = esito.modelloUsato
        fascia = Fascia.dedotta(da: quando)
    }

    private func aggiungi(identificativo: String, nome: String, testo: String) {
        guard !scelti.contains(where: { $0.identificativo == identificativo }) else { return }
        scelti.append(.init(identificativo: identificativo, nome: nome,
                            testoOriginale: testo, tipo: .esatta))
    }

    private func creaIngrediente(_ testoVoce: String) {
        let id = "utente_" + Corrispondenza.normalizza(testoVoce)
        guard !ingredienti.contains(where: { $0.identificativo == id }) else { return }
        let etichetta = testoVoce.prefix(1).uppercased() + testoVoce.dropFirst()
        let nuovo = Ingrediente(identificativo: id, nomeIt: etichetta, nomeEn: etichetta,
                                categoriaIt: "Aggiunti da me", categoriaEn: "Added by me",
                                creatoDallUtente: true)
        contesto.insert(nuovo)
        try? contesto.save()
        aggiungi(identificativo: id, nome: etichetta, testo: testoVoce)
        candidati.removeAll { $0 == testoVoce }
    }

    private func salva() {
        let pasto: Pasto
        if let p = pastoDaModificare {
            pasto = p
            for v in p.voci ?? [] { contesto.delete(v) }
            p.voci = []
            p.quando = quando
            p.fascia = fascia
            p.testoGrezzo = testo
        } else {
            pasto = Pasto(quando: quando, fascia: fascia, stato: .registrato,
                          fonte: modelloUsato ? .dettatura : .manuale, testoGrezzo: testo)
            contesto.insert(pasto)
        }
        pasto.stato = .registrato

        let perId = Dictionary(ingredienti.map { ($0.identificativo, $0) }, uniquingKeysWith: { a, _ in a })
        for r in scelti {
            guard let ingrediente = perId[r.identificativo] else { continue }
            let voce = VoceDiPasto(ingrediente: ingrediente,
                                   quantita: quantita[r.identificativo] ?? .normale,
                                   testoOriginale: r.testoOriginale)
            voce.pasto = pasto
            contesto.insert(voce)
        }
        try? contesto.save()
        chiudi()
    }
}

// MARK: - Supporto

struct IdentificabileTesto: Identifiable, Hashable {
    var testo: String
    var id: String { testo }
}

extension Corrispondenza.Riconosciuto: Identifiable {
    var id: String { identificativo }
}

/// Disposizione a capo automatico per le etichette.
struct FlussoEtichette<Dato: Identifiable, Contenuto: View>: View {
    let dati: [Dato]
    let contenuto: (Dato) -> Contenuto

    init(_ dati: [Dato], @ViewBuilder contenuto: @escaping (Dato) -> Contenuto) {
        self.dati = dati
        self.contenuto = contenuto
    }

    var body: some View {
        DisposizioneAFlusso(spaziaturaOrizzontale: 6, spaziaturaVerticale: 6) {
            ForEach(dati) { d in contenuto(d) }
        }
    }
}

struct DisposizioneAFlusso: Layout {
    var spaziaturaOrizzontale: CGFloat = 6
    var spaziaturaVerticale: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let larghezzaMassima = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, altezzaRiga: CGFloat = 0
        for v in subviews {
            let d = v.sizeThatFits(.unspecified)
            if x + d.width > larghezzaMassima, x > 0 {
                x = 0; y += altezzaRiga + spaziaturaVerticale; altezzaRiga = 0
            }
            x += d.width + spaziaturaOrizzontale
            altezzaRiga = max(altezzaRiga, d.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + altezzaRiga)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, altezzaRiga: CGFloat = 0
        for v in subviews {
            let d = v.sizeThatFits(.unspecified)
            if x + d.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += altezzaRiga + spaziaturaVerticale; altezzaRiga = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(d))
            x += d.width + spaziaturaOrizzontale
            altezzaRiga = max(altezzaRiga, d.height)
        }
    }
}

/// Catalogo completo, con le voci del 2020 in cima perche' sono quelle che
/// ha davvero mangiato.
struct CatalogoIngredientiView: View {
    @Environment(\.dismiss) private var chiudi
    @Environment(\.locale) private var locale
    @Query(sort: \Ingrediente.nomeEn) private var ingredienti: [Ingrediente]

    let giaScelti: Set<String>
    let scelto: (Ingrediente) -> Void

    @State private var ricerca = ""

    private var raggruppati: [(String, [Ingrediente])] {
        let filtrati = ingredienti.filter { i in
            guard !i.archiviato else { return false }
            guard !ricerca.isEmpty else { return true }
            let q = Corrispondenza.normalizza(ricerca)
            return i.formeRiconoscibili.contains { Corrispondenza.normalizza($0).contains(q) }
        }
        return Dictionary(grouping: filtrati, by: { $0.categoria(locale) })
            .map { ($0.key, $0.value.sorted {
                ($0.esposizioni2020, $1.nome(locale)) > ($1.esposizioni2020, $0.nome(locale)) }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(raggruppati, id: \.0) { categoria, voci in
                    Section(categoria) {
                        ForEach(voci) { i in
                            Button {
                                scelto(i); chiudi()
                            } label: {
                                HStack {
                                    Text(i.nome(locale))
                                    Spacer()
                                    if i.esposizioni2020 > 0 {
                                        Text("\(i.esposizioni2020)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    if giaScelti.contains(i.identificativo) {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $ricerca, prompt: "Search an ingredient")
            .navigationTitle("Catalogue")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { chiudi() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}
