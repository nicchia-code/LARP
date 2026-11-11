import AVFoundation
import CoreAudio
import Synchronization

/// Whether a system audio tap has been created since the app started: the one fact about the system
/// audio permission that can be read without asking. A tap is created and destroyed to probe the
/// permission (accepting a proposal, the welcome window) and again to record the system audio; each
/// success is remembered here, in memory only, and never saved.
final class SystemAudioGrantMemory: Sendable {
    /// The memory of the app: the recorder, the welcome window and the audio capture all use it.
    static let shared = SystemAudioGrantMemory()

    private let succeeded = Mutex(false)

    /// A system audio tap was created since the app started.
    var hasSucceeded: Bool {
        succeeded.withLock { $0 }
    }

    /// A system audio tap was created.
    func remember() {
        succeeded.withLock { $0 = true }
    }
}

/// Checks the real permissions: the microphone through `AVAudioApplication`, the
/// system audio by creating (and immediately destroying) a Core Audio process tap.
struct SystemRecordingPermissions: RecordingPermissions {
    private let memory: SystemAudioGrantMemory
    private let createTap: @Sendable () -> Bool

    init(
        memory: SystemAudioGrantMemory = .shared,
        createTap: @escaping @Sendable () -> Bool = SystemRecordingPermissions.createAndDestroyTap
    ) {
        self.memory = memory
        self.createTap = createTap
    }

    func missingPermission(requireSystemAudio: Bool) async -> RecordingPermission? {
        guard await microphoneGranted() else { return .microphone }
        if requireSystemAudio, !systemAudioGranted() { return .systemAudio }
        return nil
    }

    /// Both permissions already granted, without asking: the microphone through
    /// `AVAudioApplication`, the system audio only when a system audio tap was already created since
    /// the app started (creating one would make macOS ask when the user has not decided yet, and no
    /// public API tells the state of this permission without asking). So the first call after each
    /// launch of the app goes through the proposal, which creates the tap when accepted.
    func bothGrantedWithoutAsking() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted && systemAudioGrantedWithoutAsking()
    }

    /// A system audio tap was created since the app started; nothing is asked.
    func systemAudioGrantedWithoutAsking() -> Bool {
        memory.hasSucceeded
    }

    private func microphoneGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: true
        case .undetermined: await AVAudioApplication.requestRecordPermission()
        default: false
        }
    }

    /// The tap creation fails when the system audio recording permission is
    /// denied; the first attempt makes the system ask for it. A tap that is created is
    /// remembered for `systemAudioGrantedWithoutAsking()`.
    func systemAudioGranted() -> Bool {
        guard createTap() else { return false }
        memory.remember()
        return true
    }

    /// Creates a private global process tap that excludes the app's own process and destroys it at once.
    @Sendable static func createAndDestroyTap() -> Bool {
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
