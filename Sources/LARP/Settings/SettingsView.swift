import SwiftUI

/// Content of the Settings scene: the transcription language with its status
/// and the "Avvia all'accesso" switch. Values live in `UserDefaults` under the
/// keys of `SettingsKey`.
struct SettingsView: View {
    private let language: TranscriptionLanguageController
    @State private var launchAtLogin = LaunchAtLogin()

    init(language: TranscriptionLanguageController = .shared) {
        self.language = language
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
        .onAppear { launchAtLogin.refresh() }
    }

    static func statusText(_ status: TranscriptionLanguageController.Status) -> String {
        switch status {
        case .checking: "Verifica in corso…"
        case .downloading: "Download in corso…"
        case .missing: "Non disponibile, nuovo tentativo appena possibile"
        case .ready: "Pronta"
        }
    }
}

#Preview {
    SettingsView()
}
