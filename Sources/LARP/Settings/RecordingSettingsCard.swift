import SwiftUI

/// The **Registrazione** section of the settings page: "Rileva le call" with a switch, "App da
/// sorvegliare" with one chip per known call app (Microsoft Teams first), "Registra automaticamente
/// le call rilevate" with a switch and "Microfono" with the choice box.
struct RecordingSettingsCard: View {
    private let detection: CallDetectionController
    private let autoRecording: AutoRecordingController

    init(detection: CallDetectionController = .shared, autoRecording: AutoRecordingController = .shared) {
        self.detection = detection
        self.autoRecording = autoRecording
    }

    /// The known call apps as the chips show them: Microsoft Teams first, the others in the order of
    /// the table of known call apps.
    static var chipOrder: [CallApp] {
        let teams = KnownCallApps.all.filter { $0.name == "Microsoft Teams" }
        return teams + KnownCallApps.all.filter { $0.name != "Microsoft Teams" }
    }

    var body: some View {
        SettingsCard(title: "Registrazione") {
            SettingsRow(
                "Rileva le call",
                explanation: "Propone di registrare quando una call parte in un'app sorvegliata"
            ) {
                // `user.TURN_ON_CALL_DETECTION` / `user.TURN_OFF_CALL_DETECTION`.
                LARPSwitch(
                    isOn: Binding(
                        get: { detection.isOn },
                        set: { $0 ? detection.turnOn() : detection.turnOff() }
                    )
                )
                .accessibilityLabel("Rileva le call")
            }
            SettingsRow("App da sorvegliare") {
                EmptyView()
            } below: {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(Self.chipOrder, id: \.name) { app in
                        // `user.WATCH_APP` / `user.UNWATCH_APP`.
                        LARPChip(title: LocalizedStringKey(app.name), isSelected: detection.isWatched(app)) {
                            if detection.isWatched(app) { detection.unwatch(app) } else { detection.watch(app) }
                        }
                    }
                }
                .disabled(!detection.isOn)
                .opacity(detection.isOn ? 1 : 0.4)
            }
            SettingsRow(
                "Registra automaticamente le call rilevate",
                explanation: "Salta la proposta quando i permessi sono già concessi"
            ) {
                // `user.TURN_ON_AUTO_RECORDING` / `user.TURN_OFF_AUTO_RECORDING`.
                LARPSwitch(
                    isOn: Binding(
                        get: { autoRecording.isOn },
                        set: { $0 ? autoRecording.turnOn() : autoRecording.turnOff() }
                    )
                )
                .accessibilityLabel("Registra automaticamente le call rilevate")
            }
            // `user.CHOOSE_MICROPHONE`.
            SettingsRow("Microfono") {
                MicrophoneChoiceBox(minWidth: 180)
            }
        }
    }
}
