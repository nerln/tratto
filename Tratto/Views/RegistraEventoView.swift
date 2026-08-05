import SwiftUI
import SwiftData

/// Tre tocchi: aprire, scegliere la forma, salvare.
///
/// Urgenza e dolore restano sotto, opzionali, e non bloccano mai il
/// salvataggio: un campo obbligatorio in più è il modo più rapido per far
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
                        DatePicker("Time", selection: $quando)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    } label: {
                        HStack {
                            Text("Time")
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
            .navigationTitle(evento == nil ? "Bathroom" : "Edit")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { chiudi() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { salva() }.disabled(forma == nil)
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
            Text("Optional").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            Slider0a10(titolo: "Urgency", attivo: $usaUrgenza, valore: $urgenza)
            Slider0a10(titolo: "Pain at the time", attivo: $usaDolore, valore: $dolore)

            Toggle("I noticed blood", isOn: $sangue)
                .font(.callout)

            TextField("Notes", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private var avvisoSangue: some View {
        Label {
            Text("Blood in your stool is something to show a doctor, even if it happens only once and even if you already have an explanation. Tratto just records it.")
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
    let titolo: LocalizedStringKey
    @Binding var attivo: Bool
    @Binding var valore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titolo).font(.callout)
                Spacer()
                if attivo {
                    Text("\(Int(valore.rounded()))")
                        .font(.callout.monospacedDigit())
                } else {
                    Text("not set")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
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
/// È il dolore e non la forma perché nel diario del 2020 il dolore, in questa
/// forma, non è mai stato misurato: è l'unica variabile su cui non si sa già
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
                Section("Worst abdominal pain in the last 24 hours") {
                    Slider0a10(titolo: "From 0 to 10", attivo: $usaDolore, valore: $dolore)
                    Text("0 means no pain at all, 10 the worst you can imagine.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Bloating") {
                    Slider0a10(titolo: "From 0 to 10", attivo: $usaGonfiore, valore: $gonfiore)
                }
                Section("How the day went") {
                    Slider0a10(titolo: "Stress", attivo: $usaStress, valore: $stress)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Hours of sleep")
                            Spacer()
                            if usaSonno {
                                Text(Formati.decimale(oreSonno))
                            } else {
                                Text("not set").foregroundStyle(.secondary)
                            }
                        }
                        Slider(value: $oreSonno, in: 0...12, step: 0.5)
                            .onChange(of: oreSonno) { usaSonno = true }
                    }
                    Stepper("Coffees: \(caffe)", value: $caffe, in: 0...10)
                    Toggle("I drank alcohol", isOn: $alcol)
                    Toggle("I exercised", isOn: $esercizio)
                    Toggle("Unusual day", isOn: $atipica)
                }
                Section {
                    Text("These entries are not here to explain your symptoms. They are here to record what else was going on, because in a diary kept by one person sleep, stress and coffee move the numbers as much as food does.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(giorno.formatted(date: .abbreviated, time: .omitted))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { chiudi() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { salva() } }
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
