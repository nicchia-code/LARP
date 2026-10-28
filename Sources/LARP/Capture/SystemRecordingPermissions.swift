import AVFoundation
import CoreAudio

/// Checks the real permissions: the microphone through `AVAudioApplication`, the
/// system audio by creating (and immediately destroying) a Core Audio process tap.
struct SystemRecordingPermissions: RecordingPermissions {
    func missingPermission(requireSystemAudio: Bool) async -> RecordingPermission? {
        guard await microphoneGranted() else { return .microphone }
        if requireSystemAudio, !systemAudioGranted() { return .systemAudio }
        return nil
    }

    private func microphoneGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: true
        case .undetermined: await AVAudioApplication.requestRecordPermission()
        default: false
        }
    }

    /// The tap creation fails when the system audio recording permission is
    /// denied; the first attempt makes the system ask for it.
    private func systemAudioGranted() -> Bool {
        var excluded: [AudioObjectID] = []
        if let own = CoreAudioProcesses.processObject(forPID: ProcessInfo.processInfo.processIdentifier) {
            excluded.append(own)
        }
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.isPrivate = true
        var tap = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tap) == noErr else { return false }
        AudioHardwareDestroyProcessTap(tap)
        return true
    }
}
