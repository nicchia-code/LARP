import Foundation
import Observation

/// How long the audio of the calls is kept.
enum AudioRetention: Equatable, Sendable, CaseIterable {
    /// "Sempre": until the call is deleted.
    case forever
    /// "Per 30 giorni".
    case thirtyDays
    /// "Per 90 giorni".
    case ninetyDays

    /// The days the audio is kept for, `nil` for always.
    var days: Int? {
        switch self {
        case .forever: nil
        case .thirtyDays: 30
        case .ninetyDays: 90
        }
    }

    /// The text of the choice.
    var title: String {
        switch self {
        case .forever: L10n.string("Sempre")
        case .thirtyDays: L10n.string("Per 30 giorni")
        case .ninetyDays: L10n.string("Per 90 giorni")
        }
    }

    /// The retention a saved number of days stands for: 30 or 90, and "Sempre" for anything else.
    init(storedDays: Int?) {
        switch storedDays {
        case 30: self = .thirtyDays
        case 90: self = .ninetyDays
        default: self = .forever
        }
    }
}

/// The `audio-retention` machine: how long the audio of the calls is kept.
///
/// - `Keep forever` (initial, unless a limit was chosen): the audio stays until its call is deleted.
/// - `Keep for a time`: the audio of a ready call is deleted once 30 or 90 days have passed since its
///   start. The calls are looked at when the app launches, every hour and after every new limit.
///
/// The settings never depend on the call layer: the app entry point wires what `limitEvents` says to
/// the check of the call lifecycle.
@MainActor
@Observable
final class AudioRetentionController {
    /// The controller shared by the app: the settings page and the call lifecycle read the same
    /// instance.
    static let shared = AudioRetentionController()

    private(set) var retention: AudioRetention

    /// `user.CHOOSE_AUDIO_RETENTION` with a limit that makes the audio of the older calls go at once.
    @ObservationIgnored private let limitChosen = EventBroadcaster<Int>()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: SettingsKey.audioRetentionDays) as? Int
        retention = AudioRetention(storedDays: stored)
    }

    /// `user.CHOOSE_AUDIO_RETENTION`: the choice is saved. A limit different from the one in force is
    /// told to `limitEvents`, so that the audio of the ready calls older than it is deleted at once;
    /// "Sempre" deletes nothing, and audio already deleted does not come back. Choosing what is
    /// already chosen changes nothing.
    func choose(_ choice: AudioRetention) {
        guard choice != retention else { return }
        retention = choice
        if let days = choice.days {
            defaults.set(days, forKey: SettingsKey.audioRetentionDays)
            limitChosen.emit(days)
        } else {
            defaults.removeObject(forKey: SettingsKey.audioRetentionDays)
        }
    }

    /// A new stream that yields the days of every limit chosen.
    var limitEvents: AsyncStream<Int> {
        limitChosen.stream()
    }
}
