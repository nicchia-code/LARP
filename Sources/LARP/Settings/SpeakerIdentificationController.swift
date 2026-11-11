import Foundation
import Observation

/// The `speaker-identification` machine: whether Microsoft Teams and the calendar give names to the
/// participants of calls: the names given on their own after the separation of voices, the names of
/// the speakers in the live window and the names offered when renaming a participant. Titles of
/// calls and what the proposal shows do not depend on it.
///
/// The switch lives in `UserDefaults` (`settings.speakerIdentification`) and is on by default. Turning
/// it off keeps the names already given; turning it on applies to the separations that end after it:
/// whoever needs to know reads `isOn` when it matters.
@MainActor
@Observable
final class SpeakerIdentificationController {
    /// States of the `speaker-identification` machine.
    enum State: Sendable, Equatable {
        case on
        case off
    }

    /// The controller shared by the app: the settings page, the call machine and the live window
    /// read the same instance.
    static let shared = SpeakerIdentificationController()

    private(set) var state: State

    var isOn: Bool { state == .on }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Absent means on.
        state = (defaults.object(forKey: SettingsKey.speakerIdentification) as? Bool ?? true) ? .on : .off
    }

    /// `user.TURN_ON_SPEAKER_IDENTIFICATION`: Off → On; the choice is saved.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.speakerIdentification)
        state = .on
    }

    /// `user.TURN_OFF_SPEAKER_IDENTIFICATION`: On → Off; the choice is saved.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.speakerIdentification)
        state = .off
    }
}
