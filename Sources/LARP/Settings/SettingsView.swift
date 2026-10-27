import SwiftUI

/// Content of the Settings scene: the transcription language with its status,
/// the "Rifinisci il testo con omp" switch with the status of omp, and the
/// "Avvia all'accesso" switch. Values live in `UserDefaults` under the
/// keys of `SettingsKey`.
struct SettingsView: View {
    private let language: TranscriptionLanguageController
    private let refinement: TranscriptRefinementController
    @State private var launchAtLogin = LaunchAtLogin()

    init(
        language: TranscriptionLanguageController = .shared,
        refinement: TranscriptRefinementController = .shared
    ) {
        self.language = language
        self.refinement = refinement
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
                    HStack(spacing: 6) {
                        Text("Rifinisci il testo con omp")
                        if let text = Self.assistantText(refinement.state) {
                            if refinement.state == .checking {
                                ProgressView().controlSize(.small)
                            }
                            Text(text)
                                .foregroundStyle(refinement.state == .assistantMissing ? .orange : .secondary)
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
            refinement.openSettings()
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

    /// Status of omp shown next to the switch; none while refinement is off.
    static func assistantText(_ state: TranscriptRefinementController.State) -> String? {
        switch state {
        case .off: nil
        case .checking: "Verifica in corso…"
        case .assistantReady: "omp pronto"
        case .assistantMissing: "omp non trovato"
        }
    }
}

#Preview {
    SettingsView()
}
