import SwiftUI

/// Content of the Settings scene: the transcription language with its status,
/// the "Rifinisci il testo con omp" and "Sintesi con omp" switches with the status
/// of omp once below them, and the "Avvia all'accesso" switch. Values live in
/// `UserDefaults` under the keys of `SettingsKey`.
struct SettingsView: View {
    private let language: TranscriptionLanguageController
    private let refinement: TranscriptRefinementController
    private let summaries: CallSummariesController
    private let assistantStatus: AssistantStatusController
    @State private var launchAtLogin = LaunchAtLogin()

    init(
        language: TranscriptionLanguageController = .shared,
        refinement: TranscriptRefinementController = .shared,
        summaries: CallSummariesController = .shared,
        assistantStatus: AssistantStatusController = .shared
    ) {
        self.language = language
        self.refinement = refinement
        self.summaries = summaries
        self.assistantStatus = assistantStatus
    }

    var body: some View {
        Form {
            Section {
                Picker(
                    "Lingua di trascrizione",
                    selection: Binding(
                        get: { language.language },
                        set: { language.choose($0) }
                    )
                ) {
                    ForEach(TranscriptionLanguage.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                LabeledContent("Stato") {
                    HStack(spacing: 6) {
                        if language.status == .downloading || language.status == .checking {
                            ProgressView().controlSize(.small)
                        }
                        Text(Self.statusText(language.status))
                            .foregroundStyle(language.status == .missing ? .orange : .secondary)
                    }
                }
            } footer: {
                Text("Vale per le registrazioni che iniziano dopo la scelta.")
            }

            Section {
                Toggle(
                    isOn: Binding(
                        get: { refinement.isOn },
                        set: { $0 ? refinement.turnOn() : refinement.turnOff() }
                    )
                ) {
                    Text("Rifinisci il testo con omp")
                }
                Toggle(
                    isOn: Binding(
                        get: { summaries.isOn },
                        set: { $0 ? summaries.turnOn() : summaries.turnOff() }
                    )
                ) {
                    Text("Sintesi con omp")
                }
                if let text = Self.assistantText(assistantStatus.state) {
                    LabeledContent("omp") {
                        HStack(spacing: 6) {
                            if assistantStatus.state == .checking {
                                ProgressView().controlSize(.small)
                            }
                            Text(text)
                                .foregroundStyle(assistantStatus.state == .assistantMissing ? .orange : .secondary)
                        }
                    }
                }
            }

            Section {
                Toggle(
                    "Avvia all'accesso",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                if launchAtLogin.requiresApproval {
                    Text("Approva LARP in Impostazioni di Sistema › Generali › Elementi login.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            launchAtLogin.refresh()
            assistantStatus.openSettings()
        }
    }

    static func statusText(_ status: TranscriptionLanguageController.Status) -> String {
        switch status {
        case .checking: "Verifica in corso…"
        case .downloading: "Download in corso…"
        case .missing: "Non disponibile, nuovo tentativo appena possibile"
        case .ready: "Pronta"
        }
    }

    /// Status of omp shown below the switches; none while omp is not needed.
    static func assistantText(_ state: AssistantStatusController.State) -> String? {
        switch state {
        case .notNeeded: nil
        case .checking: "Verifica in corso…"
        case .assistantReady: "omp pronto"
        case .assistantMissing: "omp non trovato"
        }
    }
}

#Preview {
    SettingsView()
}
