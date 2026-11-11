import Foundation

/// A permission needed to record a call.
enum RecordingPermission: Equatable, Sendable {
    case microphone
    case systemAudio

    /// Name of the permission as the user sees it in System Settings, in the interface language.
    var name: String {
        name(language: .current)
    }

    func name(language: AppLanguage) -> String {
        switch self {
        case .microphone: L10n.string("Microfono", language: language)
        case .systemAudio: L10n.string("Registrazione audio di sistema", language: language)
        }
    }

    var alertTitle: String {
        alertTitle(language: .current)
    }

    func alertTitle(language: AppLanguage) -> String {
        switch self {
        case .microphone: L10n.string("Permesso del microfono mancante", language: language)
        case .systemAudio: L10n.string("Permesso di registrazione dell'audio di sistema mancante", language: language)
        }
    }

    /// Says which permission is missing and how to grant it.
    var alertMessage: String {
        alertMessage(language: .current)
    }

    func alertMessage(language: AppLanguage) -> String {
        L10n.format(
            "LARP non può registrare senza il permesso «%@». "
                + "Aprire Impostazioni di Sistema › Privacy e sicurezza › %@ e attivare LARP, poi riprovare.",
            name(language: language), name(language: language), language: language)
    }

    /// The pane of System Settings where the permission is granted.
    var settingsURL: URL {
        switch self {
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .systemAudio:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
        }
    }
}

/// Checks the permissions needed to record. Replaced in tests.
protocol RecordingPermissions: Sendable {
    /// The first permission that is missing (microphone before system audio), or
    /// `nil` if recording is allowed. The system audio permission is only checked when
    /// `requireSystemAudio` is `true` (accepting a proposal): a recording started by
    /// hand needs the microphone only. May ask the system to show its permission
    /// prompt when the user has not decided yet.
    func missingPermission(requireSystemAudio: Bool) async -> RecordingPermission?

    /// Whether the microphone and the system audio permissions are both already granted, read
    /// without asking the user for anything: a permission not decided yet counts as not granted.
    /// Used by automatic recording, which shows the proposal instead when this is `false`.
    func bothGrantedWithoutAsking() -> Bool
}
