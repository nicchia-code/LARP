import AppKit
import AVFoundation

/// The real permissions for the welcome window: the microphone through
/// `AVAudioApplication`, the system audio through a Core Audio process tap created and
/// destroyed at once.
struct SystemOnboardingPermissions: OnboardingPermissions {
    func microphoneAuthorization() -> MicrophoneAuthorization {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .undetermined: .undetermined
        default: .denied
        }
    }

    func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func probeSystemAudio() async -> Bool {
        SystemRecordingPermissions().systemAudioGranted()
    }

    func openSettings(for permission: RecordingPermission) {
        NSWorkspace.shared.open(permission.settingsURL)
    }
}
