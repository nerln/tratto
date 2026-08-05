import SwiftUI
import SwiftData

struct PreferenzeView: View {
    @Environment(\.modelContext) private var contesto
    @Environment(\.dismiss) private var chiudi
    @Query private var impostazioni: [Impostazioni]

    @AppStorage(Lingua.chiavePreferenza) private var linguaGrezza = Lingua.sistema.rawValue
    @State private var mostraScopo = false
    @State private var permessoNotifiche: Bool?

    private var lingua: Lingua { Lingua(rawValue: linguaGrezza) ?? .sistema }

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    Picker("Language", selection: $linguaGrezza) {
                        ForEach(Lingua.allCases) { l in
                            Text(verbatim: l.nomeNativo).tag(l.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text("The app is written in English. Italian is a translation, and the change takes effect right away.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let i = impostazioni.first {
                    Section("Usual meals") {
                        TextField("Usual breakfast", text: Binding(
                            get: { i.solitaColazione },
                            set: { i.solitaColazione = $0; try? contesto.save() }),
                                  axis: .vertical)
                        TextField("Usual snack", text: Binding(
                            get: { i.solitoSpuntino },
                            set: { i.solitoSpuntino = $0; try? contesto.save() }),
                                  axis: .vertical)
                        Text("Write them the way you would say them out loud. One tap on the Now screen logs them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("Reminders") {
                        Toggle("Remind me during the day", isOn: Binding(
                            get: { i.promemoriaAttivi },
                            set: { nuovo in
                                i.promemoriaAttivi = nuovo
                                try? contesto.save()
                                Task { await aggiornaPromemoria(nuovo, ora: i.oraPromemoriaSera) }
                            }))
                        if i.promemoriaAttivi {
                            Stepper("Evening question at \(i.oraPromemoriaSera):00",
                                    value: Binding(
                                        get: { i.oraPromemoriaSera },
                                        set: { nuovaOra in
                                            i.oraPromemoriaSera = nuovaOra
                                            try? contesto.save()
                                            Task { await aggiornaPromemoria(true, ora: nuovaOra) } }),
                                    in: 18...23)
                        }
                        if permessoNotifiche == false {
                            Text("Notifications are turned off in system settings, so the reminders will not appear.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Text("Every reminder carries a «Nothing» action: one tap and a skipped slot becomes data instead of a hole.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("What Tratto is for") { mostraScopo = true }
                    NavigationLink("2020 archive") { ArchivioView() }
                }

                Section("Version") {
                    LabeledContent("Tratto") { Text(verbatim: versione) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { chiudi() } }
            }
            .sheet(isPresented: $mostraScopo) { ScopoView() }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private var versione: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return v
    }

    private func aggiornaPromemoria(_ attivi: Bool, ora: Int) async {
        guard attivi else { Notifiche.annulla(); return }
        let concesso = await Notifiche.chiediPermesso()
        permessoNotifiche = concesso
        if concesso { await Notifiche.programma(oraSera: ora) }
    }
}

// MARK: - A che cosa serve

/// La schermata che dice, senza girarci intorno, che cosa questa app può fare
/// e che cosa no.
///
/// Serve perché la domanda con cui il progetto è nato — «quali cibi mi fanno
/// male» — è quella a cui un diario personale quasi mai riesce a rispondere,
/// mentre le ragioni per tenerlo comunque sono molte e concrete. Dirlo prima
/// evita che l'assenza di risposte venga letta come un difetto dell'app.
struct ScopoView: View {
    @Environment(\.dismiss) private var chiudi

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Sezione("What it does") {
                        Punto(Text("Records bowel movements in three taps, with their time, form, and optionally urgency and pain."))
                        Punto(Text("Records meals as ingredients, dictated or typed, and records the slots where you ate nothing."))
                        Punto(Text("Asks one question a day: the worst abdominal pain in the last 24 hours."))
                        Punto(Text("Shows how complete the diary is, how the numbers are distributed, and how much they move on their own."))
                        Punto(Text("Exports a one-page report for an appointment, plus CSV, JSON and FHIR."))
                    }

                    Sezione("What it does not do, and why") {
                        Text("Tratto never tells you that a food is causing your symptoms.")
                            .font(.callout.weight(.medium))
                        Punto(Text("Foods eaten together cannot be told apart. If rice and olive oil almost always appear in the same meal, no calculation can separate them."))
                        Punto(Text("A personal diary produces too few repetitions. Testing dozens of foods at once makes chance findings almost certain."))
                        Punto(Text("Symptoms move a lot on their own. Sleep, stress, coffee and the working week shift the numbers as much as food does."))
                        Punto(Text("In blinded challenges an inert substance triggered symptoms in about a quarter of patients. A single open test is wrong roughly one time in four."))
                        Text("An app that named a culprit anyway would not be more useful. It would be confidently wrong, and it might take a food away from you for years.")
                            .font(.callout)
                    }

                    Sezione("Who needs this diary anyway") {
                        Text("Finding the culprit is not the only reason to keep one. In most of the situations where a bowel diary is asked for, the question is different.")
                            .font(.callout)
                        Punto(Text("Before a gastroenterology appointment, when the clinician needs to see what actually happens rather than what you remember."))
                        Punto(Text("During a structured elimination and reintroduction plan run with a dietitian, where the diary is the record of the protocol."))
                        Punto(Text("When a trigger is already known — coeliac disease, a diagnosed intolerance — and what matters is adherence and how things are going."))
                        Punto(Text("Before and after a treatment or a procedure, where the point is the change over time, not the cause."))
                        Punto(Text("When someone else will read it: a diary written as you go is worth more than one reconstructed the evening before."))
                        Text("In all of these, a faithful record is the whole job. Tratto is built to do that job well and to stop there.")
                            .font(.callout)
                    }

                    Sezione("Where we put our hands up") {
                        Punto(Text("Whether a food affects you is, in most cases, not knowable from a diary alone. Tratto says so instead of guessing."))
                        Punto(Text("When coverage falls below 70% over a week, the app marks the period as not analysable rather than showing numbers that look sound."))
                        Punto(Text("Estimates of what could be detected only appear once there is enough data to compute them. Before that, any «you need N days» would be made up."))
                    }

                    Text(Testi.disclaimerEsteso)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("What Tratto is for")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { chiudi() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    private func Punto(_ t: Text) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 7)
            t.font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
