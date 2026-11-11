import Foundation
import Testing

@testable import LARP

@MainActor
private final class FakeProposals: ProposalPresenting {
    private(set) var shownApp: String?
    private(set) var showCount = 0
    private var accept: (@MainActor () -> Void)?
    private var dismiss: (@MainActor () -> Void)?

    func show(appName: String, accept: @escaping @MainActor () -> Void, dismiss: @escaping @MainActor () -> Void) {
        shownApp = appName
        showCount += 1
        self.accept = accept
        self.dismiss = dismiss
    }

    func hide() {
        shownApp = nil
        accept = nil
        dismiss = nil
    }

    /// The user taps "Registra" in the panel.
    func tapAccept() { accept?() }

    /// The user taps "Non questa" in the panel.
    func tapDismiss() { dismiss?() }
}

@MainActor
private final class FakeAlerts: PermissionAlertPresenting {
    private(set) var presented: [RecordingPermission] = []
    func present(missing permission: RecordingPermission) { presented.append(permission) }
}

@MainActor
private final class FakeEchoWarnings: EchoCancellationWarningPresenting {
    private(set) var showCount = 0
    private(set) var isShown = false
    func show() {
        showCount += 1
        isShown = true
    }
    func hide() { isShown = false }
}

@MainActor
private final class FakeSystemAudioNotices: SystemAudioUnavailablePresenting {
    /// `permissionMissing` of each time the notice was shown.
    private(set) var shown: [Bool] = []
    private(set) var isShown = false
    func show(permissionMissing: Bool) {
        shown.append(permissionMissing)
        isShown = true
    }
    func hide() { isShown = false }
}

@MainActor
private final class FakeMicrophoneLostNotices: MicrophoneLostPresenting {
    private(set) var showCount = 0
    private(set) var isShown = false
    func show() {
        showCount += 1
        isShown = true
    }
    func hide() { isShown = false }
}

@MainActor
private final class FakeSystemAudioLostNotices: SystemAudioLostPresenting {
    private(set) var showCount = 0
    private(set) var isShown = false
    func show() {
        showCount += 1
        isShown = true
    }
    func hide() { isShown = false }
}

@MainActor
private final class FakeRecordingView: RecordingViewPresenting {
    enum Call: Equatable { case started, stopped, liveWindow }
    private(set) var calls: [Call] = []
    func recordingStarted() { calls.append(.started) }
    func recordingStopped() { calls.append(.stopped) }
    func openLiveWindow() { calls.append(.liveWindow) }
}

/// The permission checks as the system answers them: the system audio one is only
/// asked when the start needs it.
private struct FakePermissions: RecordingPermissions {
    var missing: RecordingPermission?
    /// What the read that asks nothing answers.
    var grantedWithoutAsking = false
    func missingPermission(requireSystemAudio: Bool) async -> RecordingPermission? {
        missing == .systemAudio && !requireSystemAudio ? nil : missing
    }
    func bothGrantedWithoutAsking() -> Bool { grantedWithoutAsking }
}

/// The choices of the user the recorder reads: detection on, every app watched and automatic
/// recording off, as they are at the first launch.
@MainActor
private final class FakeSettings {
    var callDetectionIsOn = true
    var unwatched: Set<String> = []
    var autoRecordingIsOn = false

    var recorderSettings: Recorder.Settings {
        Recorder.Settings(
            callDetectionIsOn: { [self] in callDetectionIsOn },
            isWatched: { [self] in !unwatched.contains($0.name) },
            autoRecordingIsOn: { [self] in autoRecordingIsOn })
    }
}

private struct FakeMicSource: CallAppMicSource {
    let stream: AsyncStream<CallAppMicEvent>
    func events() -> AsyncStream<CallAppMicEvent> { stream }
}

@MainActor
private struct Fixture {
    let recorder: Recorder
    let proposals = FakeProposals()
    let alerts = FakeAlerts()
    let echoWarnings = FakeEchoWarnings()
    let systemAudioNotices = FakeSystemAudioNotices()
    let microphoneLostNotices = FakeMicrophoneLostNotices()
    let systemAudioLostNotices = FakeSystemAudioLostNotices()
    let recordingView = FakeRecordingView()
    let settings = FakeSettings()

    init(
        missing: RecordingPermission? = nil, grantedWithoutAsking: Bool = false,
        source: any CallAppMicSource = FakeMicSource(stream: AsyncStream { _ in }),
        meetings: Recorder.Meetings = .none
    ) {
        recorder = Recorder(
            micSource: source,
            permissions: FakePermissions(missing: missing, grantedWithoutAsking: grantedWithoutAsking),
            proposals: proposals,
            alerts: alerts,
            echoWarnings: echoWarnings,
            systemAudioNotices: systemAudioNotices,
            microphoneLostNotices: microphoneLostNotices,
            systemAudioLostNotices: systemAudioLostNotices,
            recordingView: recordingView,
            settings: settings.recorderSettings,
            meetings: meetings
        )
    }
}

private let zoom = KnownCallApps.app(forBundleIdentifier: "us.zoom.xos")!
private let teams = KnownCallApps.app(forBundleIdentifier: "com.microsoft.teams2")!

/// The events already emitted by the recorder.
@MainActor
private func emitted(_ recorder: Recorder, count: Int) async -> [RecorderEvent] {
    var result: [RecorderEvent] = []
    for await event in recorder.events {
        result.append(event)
        if result.count == count { break }
    }
    return result
}

@MainActor
struct RecorderTests {
    // MARK: Idle

    @Test func callAppMicStartedInIdleShowsTheProposal() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .proposing(zoom))
        #expect(f.proposals.shownApp == "Zoom")
    }

    @Test func manualStartWithAllPermissionsRecordsWithoutApp() async {
        let f = Fixture()
        await f.recorder.startRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == nil)
        #expect(await emitted(f.recorder, count: 1) == [.started(callAppName: nil)])
    }

    @Test func manualStartWithMissingMicrophonePermissionStaysIdleAndAlerts() async {
        let f = Fixture(missing: .microphone)
        await f.recorder.startRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.alerts.presented == [.microphone])
    }

    @Test func manualStartDoesNotNeedTheSystemAudioPermission() async {
        let f = Fixture(missing: .systemAudio)
        await f.recorder.startRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == nil)
        #expect(f.alerts.presented.isEmpty)
    }

    @Test func manualRecordingIgnoresCallAppStopping() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.isRecording)
    }

    // MARK: Proposing

    @Test func acceptingTheProposalRecordsTiedToTheApp() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
        #expect(f.proposals.shownApp == nil)
        #expect(await emitted(f.recorder, count: 1) == [.started(callAppName: "Zoom")])
    }

    @Test func tappingRegistraInThePanelAccepts() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.proposals.tapAccept()
        while !f.recorder.isRecording { await Task.yield() }
        #expect(f.recorder.state != .idle)
    }

    @Test func acceptingWithMissingPermissionGoesIdleAndAlerts() async {
        let f = Fixture(missing: .systemAudio)
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
        #expect(f.alerts.presented == [.systemAudio])
    }

    @Test func triggeringAppStoppingDismissesTheProposal() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
    }

    @Test func otherAppStoppingKeepsTheProposal() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.stopped(teams))
        #expect(f.recorder.state == .proposing(zoom))
    }

    @Test func menuRegistraWhileProposingAcceptsTheProposal() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.startRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
        #expect(f.proposals.shownApp == nil)
    }

    @Test func menuRegistraWhileProposingWithMissingPermissionAlertsAndDismisses() async {
        let f = Fixture(missing: .microphone)
        f.recorder.handle(.started(zoom))
        await f.recorder.startRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
        #expect(f.alerts.presented == [.microphone])
    }

    @Test func menuRegistraWhileProposingStillNeedsTheSystemAudioPermission() async {
        let f = Fixture(missing: .systemAudio)
        f.recorder.handle(.started(zoom))
        await f.recorder.startRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
        #expect(f.alerts.presented == [.systemAudio])
    }

    @Test func secondCallAppDoesNotCreateASecondProposal() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.started(teams))
        #expect(f.recorder.state == .proposing(zoom))
        #expect(f.proposals.showCount == 1)
    }

    // MARK: Recording

    @Test func stopRecordingGoesIdleAndEmitsStopped() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.stopRecording()
        #expect(f.recorder.state == .idle)
        #expect(await emitted(f.recorder, count: 2) == [.started(callAppName: nil), .stopped])
    }

    @Test func tiedAppStoppingEndsTheRecordingEvenIfAnotherAppUsesTheMic() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.recorder.handle(.started(teams))
        #expect(f.recorder.isRecording)
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
        #expect(await emitted(f.recorder, count: 2) == [.started(callAppName: "Zoom"), .stopped])
    }

    @Test func otherAppStoppingKeepsTheRecording() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.recorder.handle(.stopped(teams))
        #expect(f.recorder.isRecording)
    }

    @Test func callAppStartingWhileRecordingCreatesNothing() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.handle(.started(zoom))
        #expect(f.proposals.showCount == 0)
        #expect(f.recorder.isRecording)
    }

    @Test func stopWhileIdleDoesNothing() {
        let f = Fixture()
        f.recorder.stopRecording()
        #expect(f.recorder.state == .idle)
    }

    // MARK: Echo cancellation

    @Test func recordingStartedWithoutEchoCancellationWarnsAndKeepsRecording() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.echoCancellation(available: false))
        #expect(f.echoWarnings.isShown)
        #expect(f.recorder.isRecording)
    }

    @Test func recordingStartedWithEchoCancellationShowsNoWarning() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.recorder.captureEvent(.echoCancellation(available: true))
        #expect(f.echoWarnings.showCount == 0)
    }

    @Test func audioDevicesChangedWithoutEchoCancellationWarnsAgain() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.echoCancellation(available: false))
        f.recorder.captureEvent(.echoCancellation(available: false))
        #expect(f.echoWarnings.showCount == 2)
        #expect(f.recorder.isRecording)
    }

    @Test func audioDevicesChangedWithEchoCancellationRemovesTheWarning() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.echoCancellation(available: false))
        f.recorder.captureEvent(.echoCancellation(available: true))
        #expect(!f.echoWarnings.isShown)
        #expect(f.recorder.isRecording)
    }

    @Test func stoppingTheRecordingHidesTheWarning() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.echoCancellation(available: false))
        f.recorder.stopRecording()
        #expect(!f.echoWarnings.isShown)
    }

    @Test func echoCancellationReportOutsideARecordingIsIgnored() {
        let f = Fixture()
        f.recorder.captureEvent(.echoCancellation(available: false))
        #expect(f.echoWarnings.showCount == 0)
    }

    // MARK: System audio not available (recording started by hand)

    @Test(arguments: [true, false])
    func recordingWithoutSystemAudioTellsTheUser(permissionMissing: Bool) async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.systemAudioUnavailable(permissionMissing: permissionMissing))
        #expect(f.systemAudioNotices.shown == [permissionMissing])
        #expect(f.recorder.isRecording)
        #expect(f.echoWarnings.showCount == 0)
    }

    @Test func stoppingTheRecordingHidesTheSystemAudioNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.systemAudioUnavailable(permissionMissing: false))
        f.recorder.stopRecording()
        #expect(!f.systemAudioNotices.isShown)
    }

    @Test func systemAudioNoticeOutsideARecordingIsIgnored() {
        let f = Fixture()
        f.recorder.captureEvent(.systemAudioUnavailable(permissionMissing: true))
        #expect(f.systemAudioNotices.shown.isEmpty)
    }

    // MARK: Microphone lost notice

    @Test func recordingStartsWithoutTheMicrophoneLostNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        #expect(!f.microphoneLostNotices.isShown)
    }

    @Test func microphoneLostKeepsRecordingAndShowsTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        #expect(f.recorder.isRecording)
        #expect(f.microphoneLostNotices.isShown)
    }

    @Test func microphoneRestoredHidesTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.captureEvent(.microphoneRestored)
        #expect(!f.microphoneLostNotices.isShown)
        #expect(f.recorder.isRecording)
    }

    @Test func stopFromMicrophoneLostEndsTheRecordingAndHidesTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.stopRecording()
        #expect(f.recorder.state == .idle)
        #expect(!f.microphoneLostNotices.isShown)
        #expect(await emitted(f.recorder, count: 2) == [.started(callAppName: nil), .stopped])
    }

    @Test func tiedAppStoppingFromMicrophoneLostEndsTheRecording() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
        #expect(!f.microphoneLostNotices.isShown)
    }

    @Test func manualRecordingLostMicrophoneIgnoresCallAppStopping() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.isRecording)
    }

    @Test func nextRecordingStartsWithoutTheMicrophoneLostNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.stopRecording()
        await f.recorder.startRecording()
        #expect(f.recorder.isRecording)
        #expect(!f.microphoneLostNotices.isShown)
    }

    @Test func microphoneEventsOutsideARecordingAreIgnored() {
        let f = Fixture()
        f.recorder.captureEvent(.microphoneLost)
        #expect(f.recorder.state == .idle)
        #expect(f.microphoneLostNotices.showCount == 0)
    }

    // MARK: System audio lost

    @Test func systemAudioLostKeepsRecordingAndShowsTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.systemAudioLost)
        #expect(f.recorder.isRecording)
        #expect(f.systemAudioLostNotices.isShown)
        #expect(!f.microphoneLostNotices.isShown)
    }

    @Test func systemAudioRestoredHidesTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.systemAudioLost)
        f.recorder.captureEvent(.systemAudioRestored)
        #expect(!f.systemAudioLostNotices.isShown)
        #expect(f.recorder.isRecording)
    }

    @Test func systemAudioLostRemovesTheEchoWarning() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.echoCancellation(available: false))
        f.recorder.captureEvent(.systemAudioLost)
        #expect(!f.echoWarnings.isShown)
    }

    @Test func theNoticesOfTheMicrophoneAndTheSystemAudioAppearAndDisappearOnTheirOwn() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.captureEvent(.systemAudioLost)
        #expect(f.microphoneLostNotices.isShown && f.systemAudioLostNotices.isShown)
        f.recorder.captureEvent(.microphoneRestored)
        #expect(!f.microphoneLostNotices.isShown && f.systemAudioLostNotices.isShown)
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.captureEvent(.systemAudioRestored)
        #expect(f.microphoneLostNotices.isShown && !f.systemAudioLostNotices.isShown)
    }

    @Test func stoppingFromSystemAudioLostHidesTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.systemAudioLost)
        f.recorder.stopRecording()
        #expect(f.recorder.state == .idle)
        #expect(!f.systemAudioLostNotices.isShown)
    }

    @Test func systemAudioEventsOutsideARecordingAreIgnored() {
        let f = Fixture()
        f.recorder.captureEvent(.systemAudioLost)
        #expect(f.systemAudioLostNotices.showCount == 0)
    }

    // MARK: Source

    @Test func monitoringFeedsTheMachineFromTheSource() async {
        let (stream, continuation) = AsyncStream<CallAppMicEvent>.makeStream()
        let f = Fixture(source: FakeMicSource(stream: stream))
        f.recorder.startMonitoring()
        continuation.yield(.started(zoom))
        while f.recorder.state == .idle { await Task.yield() }
        #expect(f.recorder.state == .proposing(zoom))
        continuation.yield(.stopped(zoom))
        while f.recorder.state != .idle { await Task.yield() }
        continuation.finish()
    }
}

struct KnownCallAppsTests {
    @Test(arguments: [
        ("us.zoom.xos", "Zoom"),
        ("com.microsoft.teams2", "Microsoft Teams"),
        ("com.microsoft.teams", "Microsoft Teams"),
        ("com.apple.FaceTime", "FaceTime"),
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.hnc.Discord", "Discord"),
        ("Cisco-Systems.Spark", "Webex"),
        ("com.webex.meetingmanager", "Webex"),
        ("com.apple.Safari", "Safari"),
        ("com.google.Chrome", "Chrome"),
        ("com.microsoft.edgemac", "Edge"),
        ("org.mozilla.firefox", "Firefox"),
        ("company.thebrowser.Browser", "Arc"),
        ("com.brave.Browser", "Brave"),
    ])
    func knownBundleIdentifiers(bundleIdentifier: String, name: String) {
        #expect(KnownCallApps.app(forBundleIdentifier: bundleIdentifier)?.name == name)
    }

    @Test(arguments: [
        ("com.google.Chrome.helper", "Chrome"),
        ("com.google.Chrome.helper.Renderer", "Chrome"),
        ("com.microsoft.edgemac.helper", "Edge"),
        ("org.mozilla.plugincontainer", "Firefox"),
    ])
    func helpersMapToTheParentApp(bundleIdentifier: String, name: String) {
        #expect(KnownCallApps.app(forBundleIdentifier: bundleIdentifier)?.name == name)
    }

    @Test(arguments: ["com.apple.Music", "us.zoom", "com.google.ChromeFake", "org.mozilla"])
    func unknownBundleIdentifiers(bundleIdentifier: String) {
        #expect(KnownCallApps.app(forBundleIdentifier: bundleIdentifier) == nil)
    }

    @Test func elapsedTimeFormat() {
        #expect(Recorder.formatElapsed(0) == "0:00")
        #expect(Recorder.formatElapsed(65) == "1:05")
        #expect(Recorder.formatElapsed(3600 + 61) == "1:01:01")
    }
}

/// The "Avvia o ferma la registrazione" shortcut.
@MainActor
struct RecordingShortcutTests {
    @Test func atRestItStartsARecordingByHandAndDuringOneItStopsIt() async {
        let f = Fixture()
        await f.recorder.toggleRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == nil)

        await f.recorder.toggleRecording()
        #expect(f.recorder.state == .idle)
    }

    @Test func withAProposalShownItAcceptsIt() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.toggleRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
        #expect(f.proposals.shownApp == nil)
    }
}

/// The pause and the recording view (machine `recording-view`).
@MainActor
struct RecordingPauseAndViewTests {
    @Test func theRecordingViewFollowsTheRecording() async {
        let f = Fixture()
        await f.recorder.startRecording()
        #expect(f.recordingView.calls == [.started])
        f.recorder.stopRecording()
        #expect(f.recordingView.calls == [.started, .stopped])
    }

    @Test func aProposalAloneShowsNothing() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        #expect(f.recordingView.calls.isEmpty)
    }

    @Test func theLiveWindowOpensOnlyDuringARecording() async {
        let f = Fixture()
        f.recorder.openLiveWindow()
        #expect(f.recordingView.calls.isEmpty)
        await f.recorder.startRecording()
        f.recorder.openLiveWindow()
        #expect(f.recordingView.calls == [.started, .liveWindow])
    }

    @Test func pausingAndResumingEmitTheirEventsAndKeepTheRecording() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.pauseRecording()
        #expect(f.recorder.isPaused && f.recorder.isRecording)
        f.recorder.pauseRecording()
        f.recorder.resumeRecording()
        #expect(!f.recorder.isPaused)
        f.recorder.resumeRecording()
        f.recorder.togglePause()
        f.recorder.togglePause()
        #expect(
            await emitted(f.recorder, count: 5)
                == [.started(callAppName: nil), .paused, .resumed, .paused, .resumed])
    }

    @Test func pausingOutsideARecordingDoesNothing() {
        let f = Fixture()
        f.recorder.pauseRecording()
        f.recorder.resumeRecording()
        #expect(!f.recorder.isPaused)
    }

    @Test func stoppingWhilePausedEndsThePauseToo() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.pauseRecording()
        f.recorder.stopRecording()
        #expect(!f.recorder.isPaused)
        await f.recorder.startRecording()
        #expect(!f.recorder.isPaused)
    }
}

/// The proposal that can be discarded, call detection and automatic recording.
@MainActor
struct RecorderDetectionTests {
    // MARK: Call detection

    @Test func withDetectionOffACallAppGivesNeitherAProposalNorARecording() {
        let f = Fixture(grantedWithoutAsking: true)
        f.settings.callDetectionIsOn = false
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.showCount == 0)
    }

    @Test func anUnwatchedCallAppGivesNothingWhileTheOthersDo() {
        let f = Fixture()
        f.settings.unwatched = ["Zoom"]
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .idle)
        f.recorder.handle(.started(teams))
        #expect(f.recorder.state == .proposing(teams))
    }

    @Test func turningDetectionOffRemovesTheProposalEverywhereAndRecordsNothing() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.settings.callDetectionIsOn = false
        f.recorder.callDetectionTurnedOff()
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
        #expect(!f.recorder.isRecording)
    }

    @Test func turningDetectionOffRemovesADismissedProposalToo() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        f.settings.callDetectionIsOn = false
        f.recorder.callDetectionTurnedOff()
        #expect(f.recorder.state == .idle)
    }

    @Test func turningDetectionOffLetsTheRecordingInProgressGoOn() async {
        let f = Fixture(grantedWithoutAsking: true)
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        f.settings.callDetectionIsOn = false
        f.recorder.callDetectionTurnedOff()
        #expect(f.recorder.isRecording)
        // The recording is still tied to its call app.
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
    }

    @Test func turningDetectionOnCountsTheWatchedAppsUsingTheMicrophoneAsStarted() {
        let f = Fixture()
        f.settings.callDetectionIsOn = false
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.started(teams))
        f.settings.unwatched = ["Zoom"]
        f.settings.callDetectionIsOn = true
        f.recorder.callDetectionTurnedOn()
        #expect(f.recorder.state == .proposing(teams))
        #expect(f.proposals.shownApp == "Microsoft Teams")
    }

    @Test func severalAppsCountingAsStartedAreTakenInAlphabeticalOrder() {
        let f = Fixture()
        f.settings.callDetectionIsOn = false
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.started(teams))
        f.settings.callDetectionIsOn = true
        f.recorder.callDetectionTurnedOn()
        #expect(f.recorder.state == .proposing(teams))
        #expect(f.proposals.showCount == 1)
    }

    @Test func anAppThatStoppedWhileDetectionWasOffDoesNotCountAsStarted() {
        let f = Fixture()
        f.settings.callDetectionIsOn = false
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.stopped(zoom))
        f.settings.callDetectionIsOn = true
        f.recorder.callDetectionTurnedOn()
        #expect(f.recorder.state == .idle)
    }

    @Test func watchingAnAppAlreadyUsingTheMicrophoneCountsAsStarted() {
        let f = Fixture()
        f.settings.unwatched = ["Zoom"]
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .idle)
        f.settings.unwatched = []
        f.recorder.appWatched(zoom)
        #expect(f.recorder.state == .proposing(zoom))
    }

    @Test func watchingAnAppWhileDetectionIsOffOnlySavesTheChoice() {
        let f = Fixture()
        f.settings.callDetectionIsOn = false
        f.settings.unwatched = ["Zoom"]
        f.recorder.handle(.started(zoom))
        f.settings.unwatched = []
        f.recorder.appWatched(zoom)
        #expect(f.recorder.state == .idle)
        // Detection on again: the app, now watched, counts as started.
        f.settings.callDetectionIsOn = true
        f.recorder.callDetectionTurnedOn()
        #expect(f.recorder.state == .proposing(zoom))
    }

    @Test func watchingAnAppNotUsingTheMicrophoneDoesNothing() {
        let f = Fixture()
        f.recorder.appWatched(zoom)
        #expect(f.recorder.state == .idle)
    }

    @Test func unwatchingTheAppOfTheProposalRemovesIt() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.settings.unwatched = ["Microsoft Teams"]
        f.recorder.appUnwatched(teams)
        #expect(f.recorder.state == .proposing(zoom))
        f.settings.unwatched = ["Zoom"]
        f.recorder.appUnwatched(zoom)
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.shownApp == nil)
    }

    @Test func unwatchingTheAppOfADismissedProposalRemovesIt() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        f.recorder.appUnwatched(zoom)
        #expect(f.recorder.state == .idle)
    }

    @Test func unwatchingTheAppOfARecordingLetsItGoOn() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.settings.unwatched = ["Zoom"]
        f.recorder.appUnwatched(zoom)
        #expect(f.recorder.isRecording)
    }

    // MARK: Automatic recording

    @Test func withAutomaticRecordingAndThePermissionsGrantedTheCallIsRecordedWithoutProposal() async {
        let f = Fixture(grantedWithoutAsking: true)
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
        #expect(f.proposals.showCount == 0)
        #expect(f.alerts.presented.isEmpty)
        #expect(f.recordingView.calls == [.started])
        #expect(await emitted(f.recorder, count: 1) == [.started(callAppName: "Zoom")])
    }

    @Test func withAutomaticRecordingAndAPermissionNotGrantedYetTheProposalIsShown() {
        let f = Fixture(grantedWithoutAsking: false)
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .proposing(zoom))
        #expect(f.proposals.shownApp == "Zoom")
    }

    @Test func withoutAutomaticRecordingTheProposalIsShownEvenWithThePermissionsGranted() {
        let f = Fixture(grantedWithoutAsking: true)
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .proposing(zoom))
    }

    @Test func turningAutomaticRecordingOnLeavesTheProposalAlreadyShown() {
        let f = Fixture(grantedWithoutAsking: true)
        f.recorder.handle(.started(zoom))
        f.settings.autoRecordingIsOn = true
        #expect(f.recorder.state == .proposing(zoom))
        #expect(f.proposals.shownApp == "Zoom")
    }

    @Test func aCallAppStartingDuringAnAutomaticRecordingCreatesNothing() {
        let f = Fixture(grantedWithoutAsking: true)
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.started(teams))
        #expect(f.proposals.showCount == 0)
        f.recorder.handle(.stopped(teams))
        #expect(f.recorder.isRecording)
    }

    @Test func theAutomaticRecordingEndsWhenItsCallAppStopsEvenWhilePaused() async {
        let f = Fixture(grantedWithoutAsking: true)
        f.settings.autoRecordingIsOn = true
        f.recorder.handle(.started(zoom))
        f.recorder.pauseRecording()
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
        #expect(!f.recorder.isPaused)
        #expect(
            await emitted(f.recorder, count: 3)
                == [.started(callAppName: "Zoom"), .paused, .stopped])
    }

    @Test func aRecordingThatEndedWhileTheAppStillUsesTheMicrophoneIsNotProposedAgain() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        f.recorder.stopRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.proposals.showCount == 1)
    }

    // MARK: Proposal dismissed

    @Test func dismissingTheProposalRemovesItEverywhereAndRecordsNothing() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        #expect(f.recorder.state == .proposalDismissed(zoom))
        #expect(f.proposals.shownApp == nil)
        #expect(!f.recorder.isRecording)
        #expect(f.recordingView.calls.isEmpty)
        #expect(f.recorder.canStartRecording)
    }

    @Test func tappingNonQuestaInThePanelDismisses() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.proposals.tapDismiss()
        #expect(f.recorder.state == .proposalDismissed(zoom))
    }

    @Test func dismissingWithoutAProposalDoesNothing() {
        let f = Fixture()
        f.recorder.dismissProposal()
        #expect(f.recorder.state == .idle)
    }

    @Test func aDismissedProposalCountsAsTheOneProposal() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        f.recorder.handle(.started(teams))
        #expect(f.recorder.state == .proposalDismissed(zoom))
        #expect(f.proposals.showCount == 1)
        f.recorder.handle(.stopped(teams))
        #expect(f.recorder.state == .proposalDismissed(zoom))
    }

    @Test func aDismissedProposalCannotBeAcceptedAnyMore() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        await f.recorder.acceptProposal()
        #expect(f.recorder.state == .proposalDismissed(zoom))
    }

    @Test func theAppStoppingEndsTheDismissedProposalAndASecondUseGivesANewOne() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.state == .idle)
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.state == .proposing(zoom))
        #expect(f.proposals.showCount == 2)
    }

    @Test func startingAfterNonQuestaRecordsTheCallAppOfTheDismissedProposal() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        await f.recorder.startRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
        #expect(await emitted(f.recorder, count: 1) == [.started(callAppName: "Zoom")])
    }

    @Test func theShortcutAfterNonQuestaStartsTheRecordingOfTheCallApp() async {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        await f.recorder.toggleRecording()
        guard case .recording(let recording) = f.recorder.state else {
            Issue.record("expected recording, got \(f.recorder.state)")
            return
        }
        #expect(recording.callApp == zoom)
    }

    @Test func startingAfterNonQuestaNeedsTheSystemAudioPermissionToo() async {
        let f = Fixture(missing: .systemAudio)
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        await f.recorder.startRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.alerts.presented == [.systemAudio])
    }

    @Test func startingAfterNonQuestaNamesTheMicrophoneFirstWhenItIsMissing() async {
        let f = Fixture(missing: .microphone)
        f.recorder.handle(.started(zoom))
        f.recorder.dismissProposal()
        await f.recorder.startRecording()
        #expect(f.recorder.state == .idle)
        #expect(f.alerts.presented == [.microphone])
        // The app still uses the microphone: nothing is proposed again.
        #expect(f.proposals.showCount == 1)
    }
}

/// The recorder gives the proposal the title and the number of people of the meeting.
@MainActor
struct RecorderProposalMeetingTests {
    /// What Teams and the calendar say, as the test sets it.
    @MainActor
    private final class MeetingBox {
        var teams: TeamsReadout.Meeting?
        var event: CalendarMeeting?

        var meetings: Recorder.Meetings {
            Recorder.Meetings(teams: { [self] in teams }, calendar: { [self] in event })
        }
    }

    @Test func theCalendarEventInProgressIsReadWhenTheProposalAppearsAndForgottenWhenItGoesAway() {
        let box = MeetingBox()
        box.event = CalendarMeeting(title: "Pianificazione", invitees: ["Anna"])
        let f = Fixture(meetings: box.meetings)
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.proposalMeeting == ProposalMeeting(title: "Pianificazione", peopleCount: 2))

        // The event read at the moment of the proposal stays, whatever the calendar says later.
        box.event = nil
        #expect(f.recorder.proposalMeeting.title == "Pianificazione")

        // Teams takes over while the proposal is shown.
        box.teams = TeamsReadout.Meeting(title: "Daily", people: ["A", "B", "C"])
        #expect(f.recorder.proposalMeeting == ProposalMeeting(title: "Daily", peopleCount: 3))

        f.recorder.dismissProposal()
        box.teams = nil
        #expect(f.recorder.proposalEvent == nil)
        #expect(f.recorder.proposalMeeting == .unknown)
    }

    @Test func aCallAppThatStopsUsingTheMicrophoneDropsTheEventOfItsProposal() {
        let box = MeetingBox()
        box.event = CalendarMeeting(title: "Pianificazione", invitees: [])
        let f = Fixture(meetings: box.meetings)
        f.recorder.handle(.started(zoom))
        f.recorder.handle(.stopped(zoom))
        #expect(f.recorder.proposalEvent == nil)
    }

    @Test func acceptingTheProposalDropsTheEvent() async {
        let box = MeetingBox()
        box.event = CalendarMeeting(title: "Pianificazione", invitees: [])
        let f = Fixture(meetings: box.meetings)
        f.recorder.handle(.started(zoom))
        await f.recorder.acceptProposal()
        #expect(f.recorder.isRecording)
        #expect(f.recorder.proposalEvent == nil)
    }

    @Test func withoutAMeetingTheProposalHasNoTitleAndNoNumberOfPeople() {
        let f = Fixture()
        f.recorder.handle(.started(zoom))
        #expect(f.recorder.proposalMeeting == .unknown)
    }
}
