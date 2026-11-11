import Foundation
import Observation

/// The `auto-recording` machine: whether a detected call is recorded on its own, without a
/// proposal, when the microphone and the system audio permissions are already granted.
///
/// The switch lives in `UserDefaults` (`settings.autoRecording`) and is off by default. Turning it
/// on leaves a proposal already shown; turning it off lets a recording in progress go on: the
/// recorder only reads the switch when a call app starts using the microphone.
@MainActor
@Observable
final class AutoRecordingController {
    /// States of the `auto-recording` machine.
    enum State: Sendable, Equatable {
        case off
        case on
    }

    /// The controller shared by the app: the settings page, the popover and the recorder read the
    /// same instance.
    static let shared = AutoRecordingController()

    private(set) var state: State

    var isOn: Bool { state == .on }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.bool(forKey: SettingsKey.autoRecording) ? .on : .off
    }

    /// `user.TURN_ON_AUTO_RECORDING`: Off → On; the choice is saved.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.autoRecording)
        state = .on
    }

    /// `user.TURN_OFF_AUTO_RECORDING`: On → Off; the choice is saved.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.autoRecording)
        state = .off
    }
}
