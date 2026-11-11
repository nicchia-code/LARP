import SwiftUI

/// The **Privacy e archivio** section of the settings page: how long the audio files are kept and where
/// the archive lives.
struct PrivacySettingsCard: View {
    private let retention: AudioRetentionController
    private let location: ArchiveLocationController

    init(retention: AudioRetentionController = .shared, location: ArchiveLocationController = .shared) {
        self.retention = retention
        self.location = location
    }

    var body: some View {
        SettingsCard(title: "Privacy e archivio") {
            SettingsRow("Conserva i file audio", explanation: "Trascrizioni e sintesi restano") {
                // `user.CHOOSE_AUDIO_RETENTION`.
                LARPChoiceBox(value: retention.retention.title, minWidth: 140) {
                    ForEach(AudioRetention.allCases, id: \.self) { option in
                        Button(option.title) { retention.choose(option) }
                    }
                }
            }
            SettingsRow("Posizione dell'archivio") {
                // `user.REVEAL_ARCHIVE`: the page stays on the settings.
                Button("Mostra nel Finder") { location.reveal() }
                    .buttonStyle(.larp(.outline))
            } below: {
                Text(verbatim: location.displayPath)
                    .font(LARPFont.mono(11))
                    .foregroundStyle(LARPColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
}
