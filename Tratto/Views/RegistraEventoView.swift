import SwiftUI
import SwiftData

/// Tre tocchi: aprire, scegliere la forma, salvare.
///
/// Urgenza e dolore restano sotto, opzionali, e non bloccano mai il
/// salvataggio: un campo obbligatorio in piu' e' il modo piu' rapido per far
/// smettere di registrare.
struct RegistraEventoView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi

    var evento: EventoIntestinale?

    @State private var forma: FormaFecale?
    @State private var quando: Date = .now
    @State private var correggiOra = false
    @State private var urgenza: Double = 0
    @State private var usaUrgenza = false
    @State private var dolore: Double = 0
    @State private var usaDolore = false
    @State private var sangue = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StrisciaForme(scelta: $forma)

                    DisclosureGroup(isExpanded: $correggiOra) {
                        DatePicker("Ora", selection: $quando)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    } label: {
                        HStack {
                            Text("Ora")
                            Spacer()
                            Text(quando.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    facoltativi

                    if sangue { avvisoSangue }
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(evento == nil ? "Bagno" : "Modifica")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { chiudi() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salva() }.disabled(forma == nil)
                }
            }
            .onAppear(perform: carica)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private var facoltativi: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Facoltativo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            Slider0a10(titolo: "Urgenza", attivo: $usaUrgenza, valore: $urgenza)
            Slider0a10(titolo: "Dolore in quel momento", attivo: $usaDolore, valore: $dolore)

            Toggle("Ho notato del sangue", isOn: $sangue)
                .font(.callout)

            TextField("Note", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private var avvisoSangue: some View {
        Label {
            Text("Il sangue nelle feci è una cosa da far vedere a un medico, "
                 + "anche se succede una volta sola e anche se hai già una spiegazione. "
                 + "Tratto lo annota e basta.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.footnote)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
    }

    private func carica() {
        guard let e = evento else { return }
        forma = FormaFecale(rawValue: e.forma)
        quando = e.quando
        if let u = e.urgenza { usaUrgenza = true; urgenza = Double(u) }
        if let d = e.dolore { usaDolore = true; dolore = Double(d) }
        sangue = e.sangue
        note = e.note
    }

    private func salva() {
        guard let forma else { return }
        if let e = evento {
            e.forma = forma.rawValue
            e.quando = quando
            e.urgenza = usaUrgenza ? Int(urgenza.rounded()) : nil
            e.dolore = usaDolore ? Int(dolore.rounded()) : nil
            e.sangue = sangue
            e.note = note
        } else {
            contesto.insert(EventoIntestinale(
                quando: quando, forma: forma.rawValue,
                urgenza: usaUrgenza ? Int(urgenza.rounded()) : nil,
                dolore: usaDolore ? Int(dolore.rounded()) : nil,
                sangue: sangue, note: note))
        }
        try? contesto.save()
        chiudi()
    }
}

struct Slider0a10: View {
    let titolo: String
    @Binding var attivo: Bool
    @Binding var valore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titolo).font(.callout)
                Spacer()
                Text(attivo ? "\(Int(valore.rounded()))" : "non indicato")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(attivo ? .primary : .secondary)
            }
            Slider(value: $valore, in: 0...10, step: 1) { modifica in
                if modifica { attivo = true }
            }
            .onChange(of: valore) { attivo = true }
        }
    }
}

// MARK: - Esito della sera

/// L'esito primario: una sola domanda, una volta al giorno.
///
/// E' il dolore e non la forma perche' nel diario del 2020 il dolore, in questa
/// forma, non e' mai stato misurato: e' l'unica variabile su cui non si sa gia'
/// come si distribuisce. Ha anche l'unico codice pubblico e libero fra tutte
/// quelle in gioco (LOINC 72514-3).
struct EsitoSeraView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi

    let giorno: Date

    @State private var dolore: Double = 0
    @State private var usaDolore = false
    @State private var gonfiore: Double = 0
    @State private var usaGonfiore = false
    @State private var oreSonno: Double = 7
    @State private var usaSonno = false
    @State private var stress: Double = 0
    @State private var usaStress = false
    @State private var caffe = 0
    @State private var alcol = false
    @State private var esercizio = false
    @State private var atipica = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Il peggior dolore alla pancia nelle ultime 24 ore") {
                    Slider0a10(titolo: "Da 0 a 10", attivo: $usaDolore, valore: $dolore)
                    Text("0 vuol dire nessun dolore, 10 il peggiore che riesci a immaginare.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Gonfiore") {
                    Slider0a10(titolo: "Da 0 a 10", attivo: $usaGonfiore, valore: $gonfiore)
                }
                Section("Com'è andata la giornata") {
                    Slider0a10(titolo: "Stress", attivo: $usaStress, valore: $stress)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Ore di sonno")
                            Spacer()
                            Text(usaSonno ? Formati.decimale(oreSonno) : "non indicate")
                                .foregroundStyle(usaSonno ? .primary : .secondary)
                        }
                        Slider(value: $oreSonno, in: 0...12, step: 0.5)
                            .onChange(of: oreSonno) { usaSonno = true }
                    }
                    Stepper("Caffè: \(caffe)", value: $caffe, in: 0...10)
                    Toggle("Ho bevuto alcol", isOn: $alcol)
                    Toggle("Ho fatto attività fisica", isOn: $esercizio)
                    Toggle("Giornata fuori dal solito", isOn: $atipica)
                }
                Section {
                    Text("Queste voci non servono a spiegare i sintomi. Servono a sapere "
                         + "che cos'altro stava succedendo, perché in un diario di una persona "
                         + "sola sonno, stress e caffè muovono i numeri quanto il cibo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(giorno.formatted(date: .abbreviated, time: .omitted))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") { salva() } }
            }
            .onAppear(perform: carica)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    private func carica() {
        let g = Calendar.current.startOfDay(for: giorno)
        if let e = (try? contesto.fetch(FetchDescriptor<EsitoGiornaliero>()))?
            .first(where: { Calendar.current.isDate($0.giorno, inSameDayAs: g) }) {
            if let d = e.dolorePeggiore { usaDolore = true; dolore = Double(d) }
            if let b = e.gonfiore { usaGonfiore = true; gonfiore = Double(b) }
        }
        if let c = (try? contesto.fetch(FetchDescriptor<ContestoGiornaliero>()))?
            .first(where: { Calendar.current.isDate($0.giorno, inSameDayAs: g) }) {
            if let s = c.oreSonno { usaSonno = true; oreSonno = s }
            if let s = c.stress { usaStress = true; stress = Double(s) }
            caffe = c.caffe ?? 0
            alcol = c.alcol ?? false
            esercizio = c.esercizio ?? false
            atipica = c.giornataAtipica
        }
    }

    private func salva() {
        let g = Calendar.current.startOfDay(for: giorno)

        let esiti = (try? contesto.fetch(FetchDescriptor<EsitoGiornaliero>())) ?? []
        let esito = esiti.first { Calendar.current.isDate($0.giorno, inSameDayAs: g) }
            ?? { let e = EsitoGiornaliero(giorno: g); contesto.insert(e); return e }()
        esito.dolorePeggiore = usaDolore ? Int(dolore.rounded()) : nil
        esito.gonfiore = usaGonfiore ? Int(gonfiore.rounded()) : nil
        esito.aggiornatoIl = .now

        let contesti = (try? contesto.fetch(FetchDescriptor<ContestoGiornaliero>())) ?? []
        let ctx = contesti.first { Calendar.current.isDate($0.giorno, inSameDayAs: g) }
            ?? { let c = ContestoGiornaliero(giorno: g); contesto.insert(c); return c }()
        ctx.oreSonno = usaSonno ? oreSonno : nil
        ctx.stress = usaStress ? Int(stress.rounded()) : nil
        ctx.caffe = caffe
        ctx.alcol = alcol
        ctx.esercizio = esercizio
        ctx.giornataAtipica = atipica

        try? contesto.save()
        chiudi()
    }
}
