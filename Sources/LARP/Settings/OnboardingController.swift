import Foundation
import Observation

/// Where the microphone permission stands, read without asking.
enum MicrophoneAuthorization: Sendable, Equatable {
    case granted
    case undetermined
    /// Refused or restricted: only System Settings can change it.
    case denied
}

/// What the welcome window needs from macOS to ask for the two permissions.
/// Replaced in tests.
protocol OnboardingPermissions: Sendable {
    /// The state of the microphone permission; never asks.
    func microphoneAuthorization() -> MicrophoneAuthorization
    /// Asks the user for the microphone permission and returns whether it was granted.
    func requestMicrophone() async -> Bool
    /// Creates and destroys a system audio tap, which makes macOS ask the first time, and
    /// returns whether the permission is granted.
    func probeSystemAudio() async -> Bool
    /// Opens the pane of System Settings where `permission` is granted.
    func openSettings(for permission: RecordingPermission)
}

/// The welcome window. Replaced in tests.
@MainActor
protocol OnboardingWindowPresenting: AnyObject {
    /// Told when the user closes the window; the machine ends the welcome.
    var onUserClose: (@MainActor () -> Void)? { get set }
    /// Brings the app to the front and shows the window of `onboarding`.
    func show(for onboarding: OnboardingController)
    func close()
}

/// The `onboarding` machine: the welcome window shown once, at the first launch of
/// a version that has it. Whether it was ended lives in `UserDefaults`
/// (`SettingsKey.onboardingDone`, no by default); the step lives in memory only.
///
/// The choices of the second step are those of the settings: the views read and
/// change the same controllers.
@MainActor
@Observable
final class OnboardingController {
    /// States of the `onboarding` machine.
    enum State: Sendable, Equatable {
        /// The welcome window was never ended on this Mac.
        case notDone
        /// "Passo 1 di 2 · Permessi".
        case permissionsStep
        /// "Passo 2 di 2 · Scelte".
        case choicesStep
        /// The window is closed and never shown again.
        case done
    }

    /// The controller shared by the app.
    static let shared = OnboardingController()

    private(set) var state: State
    /// The microphone permission is granted.
    private(set) var microphoneGranted = false
    /// The system audio permission was seen granted by the last probe.
    private(set) var systemAudioGranted = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let permissions: any OnboardingPermissions
    @ObservationIgnored private let window: any OnboardingWindowPresenting

    init(
        defaults: UserDefaults = .standard,
        permissions: any OnboardingPermissions = SystemOnboardingPermissions(),
        window: any OnboardingWindowPresenting = OnboardingWindowPresenter()
    ) {
        self.defaults = defaults
        self.permissions = permissions
        self.window = window
        state = defaults.bool(forKey: SettingsKey.onboardingDone) ? .done : .notDone
        window.onUserClose = { [weak self] in self?.finishSetup() }
    }

    // MARK: Events

    /// `macos.APP_LAUNCHED`: Not done → Permissions step; the app comes to the front and
    /// the welcome window opens. Call once.
    func appLaunched() {
        guard state == .notDone else { return }
        state = .permissionsStep
        refreshMicrophone()
        window.show(for: self)
    }

    /// `user.ALLOW_MICROPHONE`: the permission is asked to the user when not decided yet;
    /// when it was refused before, System Settings opens on its pane.
    func allowMicrophone() async {
        guard state == .permissionsStep else { return }
        switch permissions.microphoneAuthorization() {
        case .granted:
            break
        case .undetermined:
            _ = await permissions.requestMicrophone()
        case .denied:
            permissions.openSettings(for: .microphone)
        }
        refreshMicrophone()
    }

    /// `user.ALLOW_SYSTEM_AUDIO`: the permission is asked by creating and destroying a
    /// system audio tap, which makes macOS ask the first time; when the tap cannot be
    /// created System Settings opens on its pane (macOS gives no way to tell a refusal
    /// from a prompt just answered without trying).
    func allowSystemAudio() async {
        guard state == .permissionsStep, !systemAudioGranted else { return }
        let granted = await permissions.probeSystemAudio()
        guard state == .permissionsStep else { return }
        systemAudioGranted = granted
        if !granted {
            permissions.openSettings(for: .systemAudio)
        }
    }

    /// `user.CONTINUE_SETUP`: Permissions step → Choices step, also when a permission is
    /// missing.
    func continueSetup() {
        guard state == .permissionsStep else { return }
        state = .choicesStep
    }

    /// `user.FINISH_SETUP`: Permissions step or Choices step → Done, with "Inizia" or by
    /// closing the window. That the welcome was ended is saved.
    func finishSetup() {
        guard state == .permissionsStep || state == .choicesStep else { return }
        state = .done
        defaults.set(true, forKey: SettingsKey.onboardingDone)
        window.close()
    }

    /// Reads the microphone permission again, for when the user comes back from System
    /// Settings.
    func refreshMicrophone() {
        microphoneGranted = permissions.microphoneAuthorization() == .granted
    }
}
