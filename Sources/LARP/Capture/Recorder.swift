import Foundation
import Observation

/// The `recorder` machine: notices that a call has started, offers to record it,
/// and starts and stops recordings. At most one recording or proposal exists at a
/// time. It emits `RecorderEvent`s; capturing and saving the audio react to them.
@MainActor
@Observable
final class Recorder {
    struct Recording: Equatable {
        /// The call app the recording is tied to, `nil` for a recording started by hand.
        let callApp: CallApp?
        let startedAt: Date
        /// The sub-state of **Recording**.
        var microphone: Microphone = .on
    }

    /// The sub-states of **Recording**.
    enum Microphone: Equatable {
        /// **Microphone on**: the microphone is being recorded.
        case on
        /// **Microphone lost**: the microphone could not start again after a change of
        /// audio devices; the recording goes on without the user's voice.
        case lost
    }

    enum State: Equatable {
        case idle
        case proposing(CallApp)
        case recording(Recording)
    }

    private(set) var state: State = .idle
    /// Seconds since the current recording started; updated every second.
    private(set) var elapsedSeconds = 0

    /// Recording start and stop events, in order. Meant for a single consumer;
    /// events emitted before iteration starts are buffered.
    @ObservationIgnored let events: AsyncStream<RecorderEvent>

    @ObservationIgnored private let eventContinuation: AsyncStream<RecorderEvent>.Continuation
    @ObservationIgnored private let micSource: any CallAppMicSource
    @ObservationIgnored private let permissions: any RecordingPermissions
    @ObservationIgnored private let proposals: any ProposalPresenting
    @ObservationIgnored private let alerts: any PermissionAlertPresenting
    @ObservationIgnored private let echoWarnings: any EchoCancellationWarningPresenting
    @ObservationIgnored private let systemAudioNotices: any SystemAudioUnavailablePresenting
    @ObservationIgnored private let microphoneLostNotices: any MicrophoneLostPresenting
    @ObservationIgnored private let systemAudioLostNotices: any SystemAudioLostPresenting
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var isCheckingPermissions = false

    init(
        micSource: any CallAppMicSource,
        permissions: any RecordingPermissions,
        proposals: any ProposalPresenting,
        alerts: any PermissionAlertPresenting,
        echoWarnings: any EchoCancellationWarningPresenting,
        systemAudioNotices: any SystemAudioUnavailablePresenting,
        microphoneLostNotices: any MicrophoneLostPresenting,
        systemAudioLostNotices: any SystemAudioLostPresenting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.micSource = micSource
        self.permissions = permissions
        self.proposals = proposals
        self.alerts = alerts
        self.echoWarnings = echoWarnings
        self.systemAudioNotices = systemAudioNotices
        self.microphoneLostNotices = microphoneLostNotices
        self.systemAudioLostNotices = systemAudioLostNotices
        self.now = now
        (events, eventContinuation) = AsyncStream<RecorderEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    /// The app's recorder, wired to Core Audio, the system permissions, the
    /// proposal panel, the permission alert and the notices of the recording.
    static let shared = Recorder(
        micSource: CoreAudioCallAppMicSource(),
        permissions: SystemRecordingPermissions(),
        proposals: ProposalPanelController(),
        alerts: PermissionAlertPresenter(),
        echoWarnings: EchoCancellationWarningPanelController(),
        systemAudioNotices: SystemAudioUnavailablePanelController(),
        microphoneLostNotices: MicrophoneLostPanelController(),
        systemAudioLostNotices: SystemAudioLostPanelController()
    )

    var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    // MARK: - Call app detection

    /// Starts reacting to call apps using the microphone. Does nothing if already started.
    func startMonitoring() {
        guard monitoringTask == nil else { return }
        let stream = micSource.events()
        monitoringTask = Task { [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    /// `CALL_APP_MIC_STARTED` / `CALL_APP_MIC_STOPPED`.
    func handle(_ event: CallAppMicEvent) {
        switch (event, state) {
        case (.started(let app), .idle):
            state = .proposing(app)
            proposals.show(appName: app.name) { [weak self] in
                Task { await self?.acceptProposal() }
            }
        case (.started, _):
            // A proposal or a recording already exists: no second one.
            break
        case (.stopped(let app), .proposing(let proposed)) where app == proposed:
            // Ignored proposal: nothing was recorded.
            state = .idle
            proposals.hide()
        case (.stopped(let app), .recording(let recording)) where app == recording.callApp:
            endRecording()
        case (.stopped, _):
            break
        }
    }

    // MARK: - User actions

    /// "Registra" in the menu: accepts the proposal when one is shown, otherwise
    /// starts a recording not tied to any call app.
    func startRecording() async {
        switch state {
        case .idle, .proposing: await beginRecording()
        case .recording: break
        }
    }

    /// "Registra" in the proposal.
    func acceptProposal() async {
        guard case .proposing = state else { return }
        await beginRecording()
    }

    /// "Ferma registrazione".
    func stopRecording() {
        guard isRecording else { return }
        endRecording()
    }

    /// What the capture reports while a recording runs; events that arrive when no
    /// recording is running are ignored.
    func captureEvent(_ event: CaptureEvent) {
        guard case .recording(var recording) = state else { return }
        switch event {
        case .echoCancellation(let available):
            // At the start of a recording and after every `macos.AUDIO_DEVICES_CHANGED`
            // that restarts the microphone (Microphone on → Microphone on). When the
            // sound of the others cannot be removed the recording goes on anyway and
            // the user is told to use headphones; otherwise a warning still shown goes away.
            if available {
                echoWarnings.hide()
            } else {
                echoWarnings.show()
            }
        case .microphoneLost:
            // `macos.AUDIO_DEVICES_CHANGED`: Microphone on → Microphone lost.
            recording.microphone = .lost
            state = .recording(recording)
            microphoneLostNotices.show()
        case .microphoneRestored:
            // `macos.AUDIO_DEVICES_CHANGED`: Microphone lost → Microphone on.
            recording.microphone = .on
            state = .recording(recording)
            microphoneLostNotices.hide()
        case .systemAudioLost:
            // `macos.AUDIO_DEVICES_CHANGED`: Captured → Lost (the `system-audio` machine).
            // Nothing is removed from the microphone any more: its warning has no reason to stay.
            echoWarnings.hide()
            systemAudioLostNotices.show()
        case .systemAudioRestored:
            // `macos.AUDIO_DEVICES_CHANGED`: Lost → Captured.
            systemAudioLostNotices.hide()
        case .systemAudioUnavailable(let permissionMissing):
            // A recording started by hand that records only the microphone.
            systemAudioNotices.show(permissionMissing: permissionMissing)
        }
    }

    // MARK: - Transitions

    /// Checks the permissions, then starts a recording tied to the app of the
    /// proposal if there is one, or tied to nothing. Accepting a proposal needs the
    /// microphone and the system audio permissions; a recording started by hand from
    /// **Idle** needs the microphone one only.
    private func beginRecording() async {
        guard !isCheckingPermissions else { return }
        let startedFromProposal: Bool
        if case .proposing = state { startedFromProposal = true } else { startedFromProposal = false }
        isCheckingPermissions = true
        let missing = await permissions.missingPermission(requireSystemAudio: startedFromProposal)
        isCheckingPermissions = false

        if let missing {
            if case .proposing = state {
                state = .idle
                proposals.hide()
            }
            alerts.present(missing: missing)
            return
        }
        switch state {
        case .idle:
            beginRecording(tiedTo: nil)
        case .proposing(let app):
            // A call app started using the microphone while the permission was being
            // asked: the system audio permission was not checked for its proposal.
            guard startedFromProposal else { return }
            proposals.hide()
            beginRecording(tiedTo: app)
        case .recording:
            break
        }
    }

    private func beginRecording(tiedTo app: CallApp?) {
        let startedAt = now()
        state = .recording(Recording(callApp: app, startedAt: startedAt))
        elapsedSeconds = 0
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                elapsedSeconds = max(0, Int(now().timeIntervalSince(startedAt)))
            }
        }
        eventContinuation.yield(.started(callAppName: app?.name))
    }

    private func endRecording() {
        tickerTask?.cancel()
        echoWarnings.hide()
        systemAudioNotices.hide()
        microphoneLostNotices.hide()
        systemAudioLostNotices.hide()
        tickerTask = nil
        state = .idle
        elapsedSeconds = 0
        eventContinuation.yield(.stopped)
    }

    /// `m:ss`, or `h:mm:ss` from one hour on.
    nonisolated static func formatElapsed(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        let (hours, minutes, secs) = (seconds / 3600, seconds % 3600 / 60, seconds % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
