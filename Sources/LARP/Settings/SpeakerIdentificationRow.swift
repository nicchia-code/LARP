import SwiftUI

/// The row "Identifica i parlanti" of the **Trascrizione** section: a switch and the explanation
/// "Usa i nomi di Teams e degli invitati del calendario".
struct SpeakerIdentificationRow: View {
    private let identification: SpeakerIdentificationController

    init(identification: SpeakerIdentificationController = .shared) {
        self.identification = identification
    }

    var body: some View {
        SettingsRow("Identifica i parlanti", explanation: "Usa i nomi di Teams e degli invitati del calendario") {
            // `user.TURN_ON_SPEAKER_IDENTIFICATION` / `user.TURN_OFF_SPEAKER_IDENTIFICATION`.
            LARPSwitch(
                isOn: Binding(
                    get: { identification.isOn },
                    set: { $0 ? identification.turnOn() : identification.turnOff() }
                )
            )
            .accessibilityLabel("Identifica i parlanti")
        }
    }
}
