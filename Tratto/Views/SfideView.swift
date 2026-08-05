import SwiftUI
import SwiftData
import Charts

/// La fase 2, e la schermata che più di ogni altra deve dire la verità prima
/// che qualcuno spenda due mesi.
struct SfideView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.locale) private var locale

    @Query(sort: \Sfida.creataIl, order: .reverse) private var sfide: [Sfida]
    @Query private var esiti: [EsitoGiornaliero]
    @Query private var eventi: [EventoIntestinale]

    @State private var mostraNuova = false
    @State private var sfidaAperta: Sfida?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if sfide.isEmpty { introduzione }

                Button {
                    mostraNuova = true
                } label: {
                    Label("Plan a comparison", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                ForEach(sfide) { s in
                    Button { sfidaAperta = s } label: { scheda(s) }
                        .buttonStyle(.plain)
                }

                Text(Testi.disclaimerEsteso).font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Comparisons")
        .sheet(isPresented: $mostraNuova) { NuovaSfidaView() }
        .sheet(item: $sfidaAperta) { s in
            DettaglioSfidaView(sfida: s, osservazioni: osservazioni)
        }
    }

    private var introduzione: some View {
        Sezione("Why a planned comparison") {
            Text("A diary records what happens. A comparison makes something happen on purpose, and that is a different kind of evidence.")
                .font(.callout)
            Punto(Text("You pick one ingredient to test and one to compare it against."))
            Punto(Text("Tratto lays out alternating blocks of days, with a gap between them, and randomises the order inside each pair."))
            Punto(Text("The plan is frozen before you start: the hypothesis, the outcome and the decision rule are fingerprinted, and the analysis refuses to run if any of them changed afterwards."))
            Punto(Text("The structure follows published reintroduction protocols. The block lengths do not: they come from how much your own numbers carry over from one day to the next."))
            Text("Before you commit, the next screen tells you how likely this is to find anything. Usually it is less than people expect.")
                .font(.callout.weight(.medium))
        }
    }

    private func scheda(_ s: Sfida) -> some View {
        let lettura = MotoreSfida.leggi(
            blocchi: s.blocchiOrdinati.map { ($0.indice, $0.condizione, $0.dal, $0.al) },
            osservazioni: osservazioni, esito: s.esito, direzione: s.direzione,
            pareggi: s.convenzionePareggi, giorniScartatiInTesta: s.giorniScartatiInTesta,
            coppiePreviste: s.blocchiPrevisti, protocolloValido: s.improntaValida)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: s.titolo.isEmpty ? s.bersaglioNome : s.titolo)
                    .font(.headline)
                Spacer()
                Text(LocalizedStringKey(lettura.verdetto.chiaveNome))
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(colore(lettura.verdetto).opacity(0.18)))
            }
            Text("\(s.bersaglioNome) vs \(s.controlloNome)")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(s.blocchiOrdinati) { b in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(b.condizione == .bersaglio ? Color.accentColor : Color.gray)
                        .opacity(b.chiuso ? 1 : 0.25)
                        .frame(height: 10)
                }
            }
            Text("\(lettura.coppie.count) of \(s.blocchiPrevisti) pairs complete")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private func colore(_ v: MotoreSfida.Verdetto) -> Color {
        switch v {
        case .coerenteConUnEffetto: .orange
        case .nessunEffettoRilevabile: .green
        case .nonConcludente, .incompleta: .gray
        case .protocolloAlterato: .red
        }
    }

    /// Una riga per giorno con quello che serve a leggere i blocchi.
    private var osservazioni: [MotoreSfida.GiornoOsservato] {
        let cal = Calendar.current
        var anormali: [Date: Bool] = [:]
        for e in eventi {
            let g = cal.startOfDay(for: e.quando)
            anormali[g] = (anormali[g] ?? false) || e.anormale
        }
        var perGiorno: [Date: MotoreSfida.GiornoOsservato] = [:]
        for e in esiti {
            let g = cal.startOfDay(for: e.giorno)
            perGiorno[g] = .init(giorno: g, dolore: e.dolorePeggiore.map(Double.init),
                                 giornataAnormale: anormali[g])
        }
        for (g, a) in anormali where perGiorno[g] == nil {
            perGiorno[g] = .init(giorno: g, dolore: nil, giornataAnormale: a)
        }
        return Array(perGiorno.values)
    }

    private func Punto(_ t: Text) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 7)
            t.font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Nuova sfida

struct NuovaSfidaView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi
    @Environment(\.locale) private var locale

    @Query private var ingredienti: [Ingrediente]

    @State private var bersaglio: String = ""
    @State private var controllo: String = ""
    @State private var esito: EsitoSfida = .dolore
    @State private var direzione: DirezioneIpotesi = .bilaterale
    @State private var coppie = 6
    @State private var giorniPerBlocco = 5
    @State private var giorniDiPausa = 4
    @State private var confermato = false

    private var candidati: [Ingrediente] {
        ingredienti.filter { !$0.archiviato }
            .sorted { ($0.esposizioni2020, $1.nome(locale)) > ($1.esposizioni2020, $0.nome(locale)) }
    }

    private var fattibilita: MotoreSfida.Fattibilita {
        MotoreSfida.fattibilita(coppie: coppie, giorniPerBlocco: giorniPerBlocco,
                                giorniDiPausa: giorniDiPausa,
                                unilaterale: direzione.unilaterale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What to compare") {
                    Picker("Target", selection: $bersaglio) {
                        Text("Choose…").tag("")
                        ForEach(candidati) { i in Text(verbatim: i.nome(locale)).tag(i.identificativo) }
                    }
                    Picker("Compared against", selection: $controllo) {
                        Text("Choose…").tag("")
                        ForEach(candidati.filter { $0.identificativo != bersaglio }) { i in
                            Text(verbatim: i.nome(locale)).tag(i.identificativo)
                        }
                    }
                    Text("Whole foods cannot be blinded: you will know which block is which. The comparison ingredient is not a placebo, it is something you do not suspect, so that expectation has something to be measured against.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("What counts as the outcome") {
                    Picker("Outcome", selection: $esito) {
                        ForEach(EsitoSfida.allCases) { e in
                            Text(LocalizedStringKey(e.chiaveNome)).tag(e)
                        }
                    }
                    Picker("Hypothesis", selection: $direzione) {
                        ForEach(DirezioneIpotesi.allCases) { d in
                            Text(LocalizedStringKey(d.chiaveNome)).tag(d)
                        }
                    }
                    Text("A one-sided hypothesis is easier to confirm, and that is exactly why it has to be chosen now and frozen. Choosing it after seeing the data is the shortcut that invalidates everything.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Shape of the plan") {
                    Stepper("\(coppie) pairs of blocks", value: $coppie, in: 3...12)
                    Stepper("\(giorniPerBlocco) days per block", value: $giorniPerBlocco, in: 3...10)
                    Stepper("\(giorniDiPausa) days of gap", value: $giorniDiPausa, in: 0...10)
                    Text("Your own series still resembles itself 3 days later and stops doing so at 4. That is where the default gap comes from, not from a protocol.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("What you can hope to see") { quadro }

                Section {
                    Toggle("I have read the numbers above", isOn: $confermato)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New comparison")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Freeze and start") { crea() }
                        .disabled(bersaglio.isEmpty || controllo.isEmpty || !confermato)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    @ViewBuilder
    private var quadro: some View {
        let f = fattibilita
        LabeledContent("Total length") { Text("\(f.giorniTotali) days") }
        LabeledContent("Pairs that must agree") { Text("\(f.concordanzeNecessarie) of \(f.coppie)") }
        LabeledContent("Smallest p you can reach") {
            Text(verbatim: Formati.decimale(f.pMinimoRaggiungibile, cifre: 3))
        }

        if !f.raggiungibile {
            Nota(colore: .red, testo: Text("With \(f.coppie) pairs no result can be significant, whatever happens. You would need at least 6 pairs for a two-sided hypothesis, or 5 for a one-sided one."))
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("If the target really did affect you…").font(.caption.weight(.semibold))
            riga("…in 7 pairs out of 10", f.potenza70)
            riga("…in 8 pairs out of 10", f.potenza80)
            riga("…in 9 pairs out of 10", f.potenza90)
            Text("These are the chances of ending up with a significant result. They are low because a comparison this short needs almost every pair to agree.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if f.coppiePerTollerareUnaDiscordanza > f.coppie {
            Text("At \(f.coppie) pairs a single pair going the other way ends the comparison without a result. The first size that tolerates one disagreement is \(f.coppiePerTollerareUnaDiscordanza) pairs.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func riga(_ etichetta: LocalizedStringKey, _ potenza: Double) -> some View {
        HStack {
            Text(etichetta).font(.caption)
            Spacer()
            Text(verbatim: Formati.percentuale(potenza))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(potenza < 0.5 ? .orange : .primary)
        }
    }

    private func crea() {
        guard let b = ingredienti.first(where: { $0.identificativo == bersaglio }),
              let c = ingredienti.first(where: { $0.identificativo == controllo }) else { return }
        let s = Sfida(titolo: "", bersaglioId: b.identificativo, bersaglioNome: b.nomeEn,
                      controlloId: c.identificativo, controlloNome: c.nomeEn,
                      esito: esito, direzione: direzione, blocchiPrevisti: coppie,
                      giorniPerBlocco: giorniPerBlocco, giorniDiPausa: giorniDiPausa)
        s.semeRandomizzazione = UInt64.random(in: 1...UInt64.max)
        s.iniziataIl = Calendar.current.startOfDay(for: .now)
        contesto.insert(s)

        for p in MotoreSfida.programma(coppie: coppie, giorniPerBlocco: giorniPerBlocco,
                                       giorniDiPausa: giorniDiPausa,
                                       inizio: s.iniziataIl ?? .now,
                                       seme: s.semeRandomizzazione) {
            let b = BloccoSfida(indice: p.indice, condizione: p.condizione, dal: p.dal, al: p.al)
            b.sfida = s
            contesto.insert(b)
        }
        // il congelamento viene per ultimo: l'impronta comprende la sequenza
        s.congelatoIl = .now
        s.improntaProtocollo = Sfida.impronta(di: s.protocolloCanonico)
        try? contesto.save()
        chiudi()
    }
}

// MARK: - Dettaglio

struct DettaglioSfidaView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi

    let sfida: Sfida
    let osservazioni: [MotoreSfida.GiornoOsservato]

    private var lettura: MotoreSfida.Lettura {
        MotoreSfida.leggi(
            blocchi: sfida.blocchiOrdinati.map { ($0.indice, $0.condizione, $0.dal, $0.al) },
            osservazioni: osservazioni, esito: sfida.esito, direzione: sfida.direzione,
            pareggi: sfida.convenzionePareggi,
            giorniScartatiInTesta: sfida.giorniScartatiInTesta,
            coppiePreviste: sfida.blocchiPrevisti, protocolloValido: sfida.improntaValida)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    protocollo
                    calendario
                    if !lettura.coppie.isEmpty { confronto }
                    risultato
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text(verbatim: sfida.bersaglioNome))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { chiudi() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 640)
        #endif
    }

    private var protocollo: some View {
        Sezione("The frozen plan") {
            LabeledContent("Target") { Text(verbatim: sfida.bersaglioNome) }
            LabeledContent("Compared against") { Text(verbatim: sfida.controlloNome) }
            LabeledContent("Outcome") { Text(LocalizedStringKey(sfida.esito.chiaveNome)) }
            LabeledContent("Hypothesis") { Text(LocalizedStringKey(sfida.direzione.chiaveNome)) }
            LabeledContent("Blocks") {
                Text("\(sfida.blocchiPrevisti) pairs of \(sfida.giorniPerBlocco) days")
            }
            if let quando = sfida.congelatoIl, let impronta = sfida.improntaProtocollo {
                LabeledContent("Frozen on") {
                    Text(quando.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Fingerprint") {
                    Text(verbatim: String(impronta.prefix(16)) + "…")
                        .font(.caption.monospaced())
                }
            }
            if !sfida.improntaValida {
                Nota(colore: .red, testo: Text("The plan no longer matches the fingerprint taken when it was frozen. The analysis will not run: a comparison whose rules changed along the way cannot be read as if they had not."))
            }
        }
    }

    private var calendario: some View {
        Sezione("Blocks") {
            ForEach(sfida.blocchiOrdinati) { b in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(b.condizione == .bersaglio ? Color.accentColor : Color.gray)
                        .frame(width: 4, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(b.condizione.chiaveNome))
                            .font(.callout.weight(.medium))
                        Text("from \(b.dal.formatted(date: .abbreviated, time: .omitted)) to \(b.al.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let v = lettura.valori.first(where: { $0.indice == b.indice }) {
                        if let valore = v.valore {
                            Text(verbatim: Formati.decimale(valore, cifre: 2))
                                .font(.callout.monospacedDigit())
                        } else {
                            Text("no data").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Block done", isOn: Binding(get: { b.chiuso },
                                                       set: { b.chiuso = $0; try? contesto.save() }))
                        .labelsHidden()
                }
            }
            Text("The first \(sfida.giorniScartatiInTesta) day of each block is left out of the calculation, to drop what carried over from the block before. It changes nothing in what you do.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var confronto: some View {
        Sezione("Pair by pair") {
            Chart(lettura.coppie, id: \.numero) { c in
                BarMark(x: .value("Pair", "\(c.numero)"),
                        y: .value("Difference", c.differenza))
                .foregroundStyle(c.differenza > 0 ? Color.orange : Color.green)
                .cornerRadius(2)
            }
            .frame(height: 130)
            Text("Each bar is one pair: the target block minus the block it was compared against. Bars all on the same side is what the test is looking for.")
                .font(.caption).foregroundStyle(.secondary)
            if lettura.coppiePerse > 0 {
                Nota(colore: .orange, testo: Text("\(lettura.coppiePerse) pairs were lost because one of the two blocks has no usable days."))
            }
        }
    }

    private var risultato: some View {
        Sezione("Result") {
            Text(LocalizedStringKey(lettura.verdetto.chiaveNome))
                .font(.title3.weight(.semibold))

            if let w = lettura.wilcoxon {
                LabeledContent("Exact p") {
                    Text(verbatim: Formati.decimale(
                        sfida.direzione.unilaterale ? w.pUnilaterale : w.pBilaterale, cifre: 4))
                }
                LabeledContent("Pairs used") { Text("\(w.coppieUsate)") }
                if w.pareggi > 0 {
                    LabeledContent("Ties") { Text("\(w.pareggi)") }
                }
                if let hl = w.stimaHodgesLehmann {
                    LabeledContent("Typical difference") {
                        Text(verbatim: Formati.decimale(hl, cifre: 2))
                    }
                }
                if let i = w.intervallo {
                    LabeledContent("Interval") {
                        Text(verbatim: "\(Formati.decimale(i.basso, cifre: 2)) … \(Formati.decimale(i.alto, cifre: 2))")
                    }
                    Text("The interval is at \(Formati.percentuale(i.confidenza)), not at 95%: with this many pairs 95% is not one of the levels that exist.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            switch lettura.verdetto {
            case .coerenteConUnEffetto:
                Text("The pairs lean the same way often enough that chance alone is an unlikely explanation. That is not the same as proof, and one comparison is not a diagnosis: an inert substance triggers symptoms in about a quarter of people. Repeat it before you act on it, and take it to a clinician.")
                    .font(.callout)
            case .nessunEffettoRilevabile:
                Text("Nothing here separates the target from what it was compared against. On a comparison this size that is the most common outcome, and it is a legitimate one: it means you can stop wondering about this ingredient for now.")
                    .font(.callout)
            case .nonConcludente:
                Text("This comparison could not have reached significance with the pairs it has, so the result says nothing either way.")
                    .font(.callout)
            case .incompleta:
                Text("Not all the pairs are finished. Looking at the result now and deciding whether to go on would break the test: the exact p is only valid if the number of pairs was fixed in advance.")
                    .font(.callout)
            case .protocolloAlterato:
                Text("The analysis is not shown because the plan changed after it was frozen.")
                    .font(.callout)
            }
        }
    }
}
