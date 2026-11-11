import Foundation
import Observation

/// The machine `playback-options`: the speed of playback and whether silences are skipped, the
/// same for every call and kept across launches.
///
/// - `Not skipping` (initial, unless skipping was left on): playback goes through every moment.
/// - `Skipping`: while playing, stretches without transcript lines are jumped over.
///
/// `user.CHANGE_SPEED` leaves the state as it is.
@MainActor
@Observable
final class PlaybackOptions {
    /// The speeds, in the order each click goes through them.
    static let speeds: [Double] = [1, 1.25, 1.5, 2, 0.75]

    /// The options shared by the app: the playback bar and the controller read the same instance.
    static let shared = PlaybackOptions()

    /// Times the audio is played at; the pitch of voices does not change with it.
    private(set) var speed: Double
    /// Whether silences are skipped while playing.
    private(set) var skipSilence: Bool

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: SettingsKey.playbackSpeed)
        speed = Self.speeds.contains(stored) ? stored : 1
        skipSilence = defaults.bool(forKey: SettingsKey.playbackSkipSilence)
    }

    /// `user.CHANGE_SPEED`: the next speed is saved and applies at once.
    func changeSpeed() {
        let index = Self.speeds.firstIndex(of: speed) ?? 0
        speed = Self.speeds[(index + 1) % Self.speeds.count]
        defaults.set(speed, forKey: SettingsKey.playbackSpeed)
    }

    /// `user.TURN_ON_SKIP_SILENCE` and `user.TURN_OFF_SKIP_SILENCE`: the choice is saved.
    func setSkipSilence(_ isOn: Bool) {
        skipSilence = isOn
        defaults.set(isOn, forKey: SettingsKey.playbackSkipSilence)
    }

    /// The speed as the chip shows it: "1,0×", "1,25×", "1,5×", "0,75×" (a point in English).
    static func label(for speed: Double, language: AppLanguage = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: speed)) ?? "\(speed)") + "×"
    }
}
