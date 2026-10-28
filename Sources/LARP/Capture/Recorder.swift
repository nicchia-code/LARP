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
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.micSource = micSource
        self.permissions = permissions
        self.proposals = proposals
        self.alerts = alerts
        self.echoWarnings = echoWarnings
        self.now = now
        (events, eventContinuation) = AsyncStream<RecorderEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    /// The app's recorder, wired to Core Audio, the system permissions, the
    /// proposal panel, the permission alert and the echo cancellation warning.
    static let shared = Recorder(
        micSource: CoreAudioCallAppMicSource(),
        permissions: SystemRecordingPermissions(),
        proposals: ProposalPanelController(),
        alerts: PermissionAlertPresenter(),
        echoWarnings: EchoCancellationWarningPanelController()
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

    /// The microphone capture reports whether the sound of the others is removed from
    /// the microphone: at the start of a recording and after every
    /// `macos.AUDIO_DEVICES_CHANGED` (the recording goes on with the new microphone or
    /// output, Recording → Recording). When it is not, the recording goes on anyway and
    /// the user is told to use headphones; otherwise a warning still shown goes away.
    func echoCancellationChanged(available: Bool) {
        guard isRecording else { return }
        if available {
            echoWarnings.hide()
        } else {
            echoWarnings.show()
        }
    }

    // MARK: - Transitions

    /// Checks the permissions, then starts a recording tied to the app of the
    /// proposal if there is one, or tied to nothing.
    private func beginRecording() async {
        guard !isCheckingPermissions else { return }
        isCheckingPermissions = true
        let missing = await permissions.missingPermission()
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
