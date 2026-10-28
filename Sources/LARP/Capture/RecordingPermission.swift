import Foundation

/// A permission needed to record a call.
enum RecordingPermission: Equatable, Sendable {
    case microphone
    case systemAudio

    /// Name of the permission as the user sees it in System Settings.
    var name: String {
        switch self {
        case .microphone: "Microfono"
        case .systemAudio: "Registrazione audio di sistema"
        }
    }

    var alertTitle: String {
        switch self {
        case .microphone: "Permesso del microfono mancante"
        case .systemAudio: "Permesso di registrazione dell'audio di sistema mancante"
        }
    }

    /// Says which permission is missing and how to grant it.
    var alertMessage: String {
        "LARP non può registrare senza il permesso «\(name)». "
            + "Aprire Impostazioni di Sistema › Privacy e sicurezza › \(name) e attivare LARP, poi riprovare."
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
}
