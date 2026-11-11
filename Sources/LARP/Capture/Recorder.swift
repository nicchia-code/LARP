import Foundation
import Observation

/// The `recorder` machine: notices that a watched call app has started using the microphone,
/// offers to record the call or records it on its own, and starts, pauses and stops recordings.
/// At most one recording or proposal exists at a time. It emits `RecorderEvent`s; capturing and
/// saving the audio react to them.
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
        /// **Proposal dismissed**: the user discarded the proposal of this call app, which still
        /// uses the microphone. It counts as the one proposal until the app stops using it.
        case proposalDismissed(CallApp)
        case recording(Recording)
    }

    /// What the recorder reads of the settings when a call app starts using the microphone.
    struct Settings {
        /// "Rileva le call" is on (`call-detection`).
        var callDetectionIsOn: @MainActor () -> Bool
        /// The call app is watched (`call-detection`).
        var isWatched: @MainActor (CallApp) -> Bool
        /// "Registra automaticamente le call rilevate" is on (`auto-recording`).
        var autoRecordingIsOn: @MainActor () -> Bool

        /// The choices of the user, kept by their controllers.
        @MainActor static var shared: Settings {
            Settings(
                callDetectionIsOn: { CallDetectionController.shared.isOn },
                isWatched: { CallDetectionController.shared.isWatched($0) },
                autoRecordingIsOn: { AutoRecordingController.shared.isOn })
        }
    }

    /// What the recorder reads of the meetings, for the card of the proposal.
    struct Meetings: Sendable {
        /// The meeting Microsoft Teams shows now (`teams-meeting`), while Teams access is allowed.
        var teams: @MainActor () -> TeamsReadout.Meeting?
        /// The calendar event in progress now (`calendar-access`), while the calendar is connected.
        var calendar: @MainActor () -> CalendarMeeting?

        /// No meeting information.
        static let none = Meetings(teams: { nil }, calendar: { nil })

        /// Teams and the calendar of the Mac.
        @MainActor static var shared: Meetings {
            Meetings(
                teams: { TeamsMeetingController.shared.meeting },
                calendar: { CalendarAccessController.shared.meetingInProgress() })
        }
    }

    private(set) var state: State = .idle
    /// Seconds since the current recording started; updated every second.
    private(set) var elapsedSeconds = 0
    /// The **Paused** sub-state of **Recording**: both tracks are written with silence.
    private(set) var isPaused = false
    /// The calendar event in progress when the proposal appeared; kept only while it is shown.
    private(set) var proposalEvent: CalendarMeeting?

    /// What the card of the proposal says: the title of the meeting Teams shows, else of the calendar
    /// event in progress when the proposal appeared, and the number of people in it. Read by the
    /// views, which follow Teams while the proposal is shown.
    var proposalMeeting: ProposalMeeting {
        ProposalMeeting.resolve(teams: meetings.teams(), event: proposalEvent)
    }

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
    @ObservationIgnored private let recordingView: any RecordingViewPresenting
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let meetings: Meetings
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var isCheckingPermissions = false
    /// The call apps using the microphone now, watched or not: a switch that makes an app count
    /// as started again needs to know which ones they are.
    @ObservationIgnored private var activeApps: Set<CallApp> = []

    init(
        micSource: any CallAppMicSource,
        permissions: any RecordingPermissions,
        proposals: any ProposalPresenting,
        alerts: any PermissionAlertPresenting,
        echoWarnings: any EchoCancellationWarningPresenting,
        systemAudioNotices: any SystemAudioUnavailablePresenting,
        microphoneLostNotices: any MicrophoneLostPresenting,
        systemAudioLostNotices: any SystemAudioLostPresenting,
        recordingView: any RecordingViewPresenting,
        settings: Settings,
        meetings: Meetings = .none,
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
        self.recordingView = recordingView
        self.settings = settings
        self.meetings = meetings
        self.now = now
        (events, eventContinuation) = AsyncStream<RecorderEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    /// The app's recorder, wired to Core Audio, the system permissions, the proposal panel, the
    /// permission alert, the notices of the recording and the settings.
    static let shared = Recorder(
        micSource: CoreAudioCallAppMicSource(),
        permissions: SystemRecordingPermissions(),
        proposals: ProposalPanelController(),
        alerts: PermissionAlertPresenter(),
        echoWarnings: EchoCancellationWarningPanelController(),
        systemAudioNotices: SystemAudioUnavailablePanelController(),
        microphoneLostNotices: MicrophoneLostPanelController(),
        systemAudioLostNotices: SystemAudioLostPanelController(),
        recordingView: RecordingViewController.shared,
        settings: .shared,
        meetings: .shared
    )

    var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    /// "Registra" and "Nuova registrazione" apply: nothing is recorded and no proposal is shown
    /// (a discarded one is not shown).
    var canStartRecording: Bool {
        switch state {
        case .idle, .proposalDismissed: true
        case .proposing, .recording: false
        }
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

    /// `macos.CALL_APP_MIC_STARTED` / `macos.CALL_APP_MIC_STOPPED`.
    func handle(_ event: CallAppMicEvent) {
        switch event {
        case .started(let app):
            activeApps.insert(app)
            callAppStarted(app)
        case .stopped(let app):
            activeApps.remove(app)
            callAppStopped(app)
        }
    }

    /// `macos.CALL_APP_MIC_STARTED`, also for an app that already used the microphone when
    /// detection or the watching of the app was turned on.
    private func callAppStarted(_ app: CallApp) {
        // A proposal, a discarded proposal or a recording already exists: no second one.
        guard state == .idle else { return }
        // Only watched call apps, and only while "Rileva le call" is on.
        guard settings.callDetectionIsOn(), settings.isWatched(app) else { return }
        if settings.autoRecordingIsOn(), permissions.bothGrantedWithoutAsking() {
            // Idle → Recording: no proposal and no permission asked; tied to the call app.
            beginRecording(tiedTo: app)
            return
        }
        // Idle → Proposing.
        proposalEvent = meetings.calendar()
        state = .proposing(app)
        proposals.show(
            appName: app.name,
            accept: { [weak self] in Task { await self?.acceptProposal() } },
            dismiss: { [weak self] in self?.dismissProposal() })
    }

    /// `macos.CALL_APP_MIC_STOPPED`.
    private func callAppStopped(_ app: CallApp) {
        switch state {
        case .proposing(let proposed) where proposed == app:
            // Ignored proposal: nothing was recorded.
            state = .idle
            proposalEvent = nil
            proposals.hide()
        case .proposalDismissed(let dismissed) where dismissed == app:
            state = .idle
        case .recording(let recording) where recording.callApp == app:
            endRecording()
        case .idle, .proposing, .proposalDismissed, .recording:
            break
        }
    }

    // MARK: - Settings

    /// `user.TURN_ON_CALL_DETECTION`: the watched apps already using the microphone count as
    /// started.
    func callDetectionTurnedOn() {
        for app in activeApps.sorted(by: { $0.name < $1.name }) {
            callAppStarted(app)
        }
    }

    /// `user.TURN_OFF_CALL_DETECTION`: Proposing → Idle and Proposal dismissed → Idle; a recording
    /// in progress goes on.
    func callDetectionTurnedOff() {
        dropProposal()
    }

    /// `user.WATCH_APP`: with detection on, an app that already uses the microphone counts as
    /// started.
    func appWatched(_ app: CallApp) {
        guard activeApps.contains(app) else { return }
        callAppStarted(app)
    }

    /// `user.UNWATCH_APP`: the proposal shown or discarded for that app goes away; a recording in
    /// progress goes on.
    func appUnwatched(_ app: CallApp) {
        switch state {
        case .proposing(let proposed) where proposed == app: dropProposal()
        case .proposalDismissed(let dismissed) where dismissed == app: dropProposal()
        case .idle, .proposing, .proposalDismissed, .recording: break
        }
    }

    /// The proposal shown or discarded disappears everywhere and nothing is recorded.
    private func dropProposal() {
        proposalEvent = nil
        switch state {
        case .proposing:
            state = .idle
            proposals.hide()
        case .proposalDismissed:
            state = .idle
        case .idle, .recording:
            break
        }
    }

    // MARK: - User actions

    /// `user.START_RECORDING`: "Registra", "Nuova registrazione" and the shortcut. Accepts the
    /// proposal when one is shown, records the call of a discarded proposal, and otherwise starts a
    /// recording not tied to any call app.
    func startRecording() async {
        switch state {
        case .idle, .proposing, .proposalDismissed: await beginRecording()
        case .recording: break
        }
    }

    /// `user.ACCEPT_PROPOSAL`: "Registra questa call".
    func acceptProposal() async {
        guard case .proposing = state else { return }
        await beginRecording()
    }

    /// `user.DISMISS_PROPOSAL`: "Non questa". The proposal disappears everywhere and nothing is
    /// recorded.
    func dismissProposal() {
        proposalEvent = nil
        guard case .proposing(let app) = state else { return }
        state = .proposalDismissed(app)
        proposals.hide()
    }

    /// `user.STOP_RECORDING`: "Ferma registrazione".
    func stopRecording() {
        guard isRecording else { return }
        endRecording()
    }

    /// The "Avvia o ferma la registrazione" shortcut: stops the recording in progress; otherwise
    /// `startRecording()`, which accepts the proposal shown or starts a recording by hand.
    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }

    /// `user.PAUSE_RECORDING`: Going on → Paused. Both tracks are written with silence from now
    /// on and so is the live transcription; the elapsed time keeps counting.
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        eventContinuation.yield(.paused)
    }

    /// `user.RESUME_RECORDING`: Paused → Going on.
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        isPaused = false
        eventContinuation.yield(.resumed)
    }

    /// "Pausa" / "Riprendi" in the pill, in the live window and in the popover.
    func togglePause() {
        if isPaused { resumeRecording() } else { pauseRecording() }
    }

    /// `user.OPEN_LIVE_WINDOW`: the pill disappears and the live window opens in front.
    /// Only during a recording.
    func openLiveWindow() {
        guard isRecording else { return }
        recordingView.openLiveWindow()
    }

    /// What the capture reports while a recording runs; events that arrive when no
    /// recording is running are ignored.
    func captureEvent(_ event: CaptureEvent) {
        guard case .recording = state else { return }
        switch event {
        case .echoCancellation(let available):
            // At the start of a recording, after every `macos.AUDIO_DEVICES_CHANGED`
            // that restarts the microphone (Microphone on → Microphone on) and when the
            // system audio comes back after being lost (`system-audio.RESTORED`), even
            // while the microphone is still lost. When the sound of the others cannot be
            // removed the recording goes on anyway and the user is told to use headphones;
            // otherwise a warning still shown goes away.
            if available {
                echoWarnings.hide()
            } else {
                echoWarnings.show()
            }
        case .microphoneLost:
            // `macos.AUDIO_DEVICES_CHANGED`: the microphone Machine goes On → Lost; the
            // recording goes on and the lasting notice is shown.
            microphoneLostNotices.show()
        case .microphoneRestored:
            // `macos.AUDIO_DEVICES_CHANGED`: the microphone Machine goes Lost → On.
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

    /// Checks the permissions, then starts a recording tied to the call app of the proposal, shown
    /// or discarded, if there is one, or tied to nothing. Accepting a proposal and starting after
    /// "Non questa" need the microphone and the system audio permissions; a recording started by
    /// hand from **Idle** needs the microphone one only.
    private func beginRecording() async {
        guard !isCheckingPermissions else { return }
        let startedFromProposal: Bool
        switch state {
        case .proposing, .proposalDismissed: startedFromProposal = true
        case .idle, .recording: startedFromProposal = false
        }
        isCheckingPermissions = true
        let missing = await permissions.missingPermission(requireSystemAudio: startedFromProposal)
        isCheckingPermissions = false

        if let missing {
            // The proposal disappears everywhere; a start by hand leaves a proposal that appeared
            // meanwhile alone. The permission alert names the first missing permission.
            if startedFromProposal { dropProposal() }
            alerts.present(missing: missing)
            return
        }
        switch state {
        case .idle:
            // The call app stopped using the microphone while the permissions were being checked
            // (or nothing was proposed): the recording is tied to no call app.
            beginRecording(tiedTo: nil)
        case .proposing(let app):
            // A call app started using the microphone while the permission was being
            // asked: the system audio permission was not checked for its proposal.
            guard startedFromProposal else { return }
            proposals.hide()
            beginRecording(tiedTo: app)
        case .proposalDismissed(let app):
            guard startedFromProposal else { return }
            beginRecording(tiedTo: app)
        case .recording:
            break
        }
    }

    private func beginRecording(tiedTo app: CallApp?) {
        let startedAt = now()
        proposalEvent = nil
        state = .recording(Recording(callApp: app, startedAt: startedAt))
        elapsedSeconds = 0
        isPaused = false
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                elapsedSeconds = max(0, Int(now().timeIntervalSince(startedAt)))
            }
        }
        // `recorder.RECORDING_STARTED`: the pill appears.
        recordingView.recordingStarted()
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
        isPaused = false
        elapsedSeconds = 0
        // `recorder.RECORDING_STOPPED`: the pill or the live window disappears.
        recordingView.recordingStopped()
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
