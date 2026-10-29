import Foundation
import Testing

@testable import LARP

@MainActor
private final class FakeProposals: ProposalPresenting {
    private(set) var shownApp: String?
    private(set) var showCount = 0
    private var accept: (@MainActor () -> Void)?

    func show(appName: String, accept: @escaping @MainActor () -> Void) {
        shownApp = appName
        showCount += 1
        self.accept = accept
    }

    func hide() {
        shownApp = nil
        accept = nil
    }

    /// The user taps "Registra" in the panel.
    func tapAccept() { accept?() }
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

/// The permission checks as the system answers them: the system audio one is only
/// asked when the start needs it.
private struct FakePermissions: RecordingPermissions {
    var missing: RecordingPermission?
    func missingPermission(requireSystemAudio: Bool) async -> RecordingPermission? {
        missing == .systemAudio && !requireSystemAudio ? nil : missing
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

    init(missing: RecordingPermission? = nil, source: any CallAppMicSource = FakeMicSource(stream: AsyncStream { _ in })) {
        recorder = Recorder(
            micSource: source,
            permissions: FakePermissions(missing: missing),
            proposals: proposals,
            alerts: alerts,
            echoWarnings: echoWarnings,
            systemAudioNotices: systemAudioNotices,
            microphoneLostNotices: microphoneLostNotices,
            systemAudioLostNotices: systemAudioLostNotices
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

    // MARK: Microphone on / Microphone lost

    private func microphone(of recorder: Recorder) -> Recorder.Microphone? {
        if case .recording(let recording) = recorder.state { recording.microphone } else { nil }
    }

    @Test func recordingStartsWithTheMicrophoneOn() async {
        let f = Fixture()
        await f.recorder.startRecording()
        #expect(microphone(of: f.recorder) == .on)
        #expect(!f.microphoneLostNotices.isShown)
    }

    @Test func microphoneLostKeepsRecordingAndShowsTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        #expect(microphone(of: f.recorder) == .lost)
        #expect(f.recorder.isRecording)
        #expect(f.microphoneLostNotices.isShown)
    }

    @Test func microphoneRestoredGoesBackToMicrophoneOnAndHidesTheNotice() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.captureEvent(.microphoneRestored)
        #expect(microphone(of: f.recorder) == .on)
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

    @Test func nextRecordingStartsWithTheMicrophoneOn() async {
        let f = Fixture()
        await f.recorder.startRecording()
        f.recorder.captureEvent(.microphoneLost)
        f.recorder.stopRecording()
        await f.recorder.startRecording()
        #expect(microphone(of: f.recorder) == .on)
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
