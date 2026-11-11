import Foundation
import Synchronization
import Testing

@testable import LARP

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

/// Permissions whose answers the test chooses; it records what was asked.
private final class FakePermissions: OnboardingPermissions {
    private struct State {
        var microphone: MicrophoneAuthorization
        var microphoneAnswer = true
        var systemAudio = true
        var microphoneRequests = 0
        var probes = 0
        var opened: [RecordingPermission] = []
    }

    private let state: Mutex<State>

    init(microphone: MicrophoneAuthorization = .undetermined) {
        state = Mutex(State(microphone: microphone))
    }

    var microphoneRequests: Int { state.withLock { $0.microphoneRequests } }
    var probes: Int { state.withLock { $0.probes } }
    var opened: [RecordingPermission] { state.withLock { $0.opened } }

    func setMicrophoneAnswer(_ granted: Bool) { state.withLock { $0.microphoneAnswer = granted } }
    func setSystemAudio(_ granted: Bool) { state.withLock { $0.systemAudio = granted } }
    func setMicrophone(_ value: MicrophoneAuthorization) { state.withLock { $0.microphone = value } }

    func microphoneAuthorization() -> MicrophoneAuthorization { state.withLock { $0.microphone } }

    func requestMicrophone() async -> Bool {
        state.withLock {
            $0.microphoneRequests += 1
            $0.microphone = $0.microphoneAnswer ? .granted : .denied
            return $0.microphoneAnswer
        }
    }

    func probeSystemAudio() async -> Bool {
        state.withLock {
            $0.probes += 1
            return $0.systemAudio
        }
    }

    func openSettings(for permission: RecordingPermission) {
        state.withLock { $0.opened.append(permission) }
    }
}

@MainActor
private final class FakeWindow: OnboardingWindowPresenting {
    var onUserClose: (@MainActor () -> Void)?
    private(set) var shown = 0
    private(set) var closed = 0

    func show(for onboarding: OnboardingController) { shown += 1 }
    func close() { closed += 1 }

    /// The user closes the window with its close button.
    func userCloses() { onUserClose?() }
}

@Suite("Onboarding")
@MainActor
struct OnboardingTests {
    @MainActor
    private struct Fixture {
        let defaults = makeDefaults()
        let permissions: FakePermissions
        let window = FakeWindow()

        init(microphone: MicrophoneAuthorization = .undetermined, done: Bool = false) {
            permissions = FakePermissions(microphone: microphone)
            if done { defaults.set(true, forKey: SettingsKey.onboardingDone) }
        }

        func controller() -> OnboardingController {
            OnboardingController(defaults: defaults, permissions: permissions, window: window)
        }
    }

    @Test("a first launch starts in Not done and the welcome is not shown before the app launches")
    func startsNotDone() {
        let f = Fixture()
        let onboarding = f.controller()
        #expect(onboarding.state == .notDone)
        #expect(f.window.shown == 0)
    }

    @Test("APP_LAUNCHED opens the welcome window on the permissions step")
    func appLaunchedOpensTheWindow() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        #expect(onboarding.state == .permissionsStep)
        #expect(f.window.shown == 1)
    }

    @Test("a welcome that was ended never comes back")
    func doneNeverComesBack() {
        let f = Fixture(done: true)
        let onboarding = f.controller()
        onboarding.appLaunched()
        #expect(onboarding.state == .done)
        #expect(f.window.shown == 0)
    }

    @Test("the permissions step shows a microphone permission already granted")
    func microphoneAlreadyGranted() {
        let f = Fixture(microphone: .granted)
        let onboarding = f.controller()
        onboarding.appLaunched()
        #expect(onboarding.microphoneGranted)
        #expect(!onboarding.systemAudioGranted)
    }

    @Test("ALLOW_MICROPHONE asks the user when the permission is not decided yet")
    func allowMicrophoneAsks() async {
        let f = Fixture(microphone: .undetermined)
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowMicrophone()
        #expect(f.permissions.microphoneRequests == 1)
        #expect(onboarding.microphoneGranted)
        #expect(f.permissions.opened.isEmpty)
    }

    @Test("a microphone permission refused in the prompt stays missing and nothing else opens")
    func allowMicrophoneRefusedInThePrompt() async {
        let f = Fixture(microphone: .undetermined)
        f.permissions.setMicrophoneAnswer(false)
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowMicrophone()
        #expect(!onboarding.microphoneGranted)
        #expect(f.permissions.opened.isEmpty)
        #expect(onboarding.state == .permissionsStep)
    }

    @Test("ALLOW_MICROPHONE opens its pane of System Settings when the permission was refused before")
    func allowMicrophoneRefusedBefore() async {
        let f = Fixture(microphone: .denied)
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowMicrophone()
        #expect(f.permissions.microphoneRequests == 0)
        #expect(f.permissions.opened == [.microphone])
        #expect(!onboarding.microphoneGranted)
    }

    @Test("coming back from System Settings shows the microphone permission just granted")
    func refreshAfterSystemSettings() async {
        let f = Fixture(microphone: .denied)
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowMicrophone()
        f.permissions.setMicrophone(.granted)
        onboarding.refreshMicrophone()
        #expect(onboarding.microphoneGranted)
    }

    @Test("ALLOW_SYSTEM_AUDIO creates a tap to ask for the permission")
    func allowSystemAudioProbes() async {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowSystemAudio()
        #expect(f.permissions.probes == 1)
        #expect(onboarding.systemAudioGranted)
        #expect(f.permissions.opened.isEmpty)
    }

    @Test("ALLOW_SYSTEM_AUDIO opens its pane of System Settings when the tap cannot be created")
    func allowSystemAudioRefused() async {
        let f = Fixture()
        f.permissions.setSystemAudio(false)
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowSystemAudio()
        #expect(!onboarding.systemAudioGranted)
        #expect(f.permissions.opened == [.systemAudio])
    }

    @Test("a permission already shown as granted is not asked again")
    func allowSystemAudioOnce() async {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        await onboarding.allowSystemAudio()
        await onboarding.allowSystemAudio()
        #expect(f.permissions.probes == 1)
    }

    @Test("CONTINUE_SETUP goes on to the choices step even with both permissions missing")
    func continueWithMissingPermissions() {
        let f = Fixture(microphone: .denied)
        let onboarding = f.controller()
        onboarding.appLaunched()
        onboarding.continueSetup()
        #expect(onboarding.state == .choicesStep)
        #expect(f.window.closed == 0)
    }

    @Test("CONTINUE_SETUP does nothing outside the permissions step")
    func continueOutsideThePermissionsStep() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.continueSetup()
        #expect(onboarding.state == .notDone)
    }

    @Test("FINISH_SETUP from the choices step closes the window and is kept across launches")
    func finishFromChoices() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        onboarding.continueSetup()
        onboarding.finishSetup()
        #expect(onboarding.state == .done)
        #expect(f.window.closed == 1)
        #expect(f.defaults.bool(forKey: SettingsKey.onboardingDone))

        let next = f.controller()
        next.appLaunched()
        #expect(next.state == .done)
        #expect(f.window.shown == 1)
    }

    @Test("closing the window on the permissions step ends the welcome")
    func finishFromPermissions() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        onboarding.finishSetup()
        #expect(onboarding.state == .done)
        #expect(f.defaults.bool(forKey: SettingsKey.onboardingDone))
    }

    @Test("FINISH_SETUP twice closes the window once")
    func finishTwice() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        onboarding.finishSetup()
        onboarding.finishSetup()
        #expect(f.window.closed == 1)
    }

    @Test("FINISH_SETUP before the welcome opened saves nothing")
    func finishBeforeOpening() {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.finishSetup()
        #expect(onboarding.state == .notDone)
        #expect(!f.defaults.bool(forKey: SettingsKey.onboardingDone))
    }

    @Test("a permission answer that arrives after the window was closed changes nothing")
    func answerAfterClosing() async {
        let f = Fixture()
        let onboarding = f.controller()
        onboarding.appLaunched()
        onboarding.finishSetup()
        await onboarding.allowSystemAudio()
        #expect(f.permissions.probes == 0)
        #expect(!onboarding.systemAudioGranted)
    }
}

@Suite("OnboardingClosing")
@MainActor
struct OnboardingClosingTests {
    @Test("the user closing the window on either step ends the welcome, and the closing it causes is not counted twice")
    func userClosesTheWindow() {
        let defaults = makeDefaults()
        let window = FakeWindow()
        let onboarding = OnboardingController(
            defaults: defaults, permissions: FakePermissions(), window: window)
        onboarding.appLaunched()
        onboarding.continueSetup()
        window.userCloses()
        #expect(onboarding.state == .done)
        #expect(defaults.bool(forKey: SettingsKey.onboardingDone))
        #expect(window.closed == 1)
        // The window reports its closing once more while it closes.
        window.userCloses()
        #expect(window.closed == 1)
    }
}
