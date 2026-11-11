import Foundation
import Observation

/// The `call-detection` machine: whether the app watches the call apps that start using the
/// microphone, and which of the known call apps it watches.
///
/// Both choices live in `UserDefaults`: `settings.callDetection` (on by default) and
/// `settings.unwatchedCallApps`, the names of the known call apps the user turned off (every other
/// known app is watched; a name no longer known is ignored). The choice of each app is kept also
/// while detection is off. The recorder reacts to the news broadcast by the `…Events` streams: the
/// app entry point forwards them, because Settings never depends on the call layer.
@MainActor
@Observable
final class CallDetectionController {
    /// States of the `call-detection` machine.
    enum State: Sendable, Equatable {
        case on
        case off
    }

    /// The controller shared by the app: the settings page, the popover and the recorder read the
    /// same instance.
    static let shared = CallDetectionController()

    private(set) var state: State
    /// The names of the known call apps that are not watched.
    private(set) var unwatchedNames: Set<String>

    /// Detection is on: watched call apps give proposals and automatic recordings.
    var isOn: Bool { state == .on }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let knownApps: [CallApp]
    @ObservationIgnored private let turnedOn = EventBroadcaster<Void>()
    @ObservationIgnored private let turnedOff = EventBroadcaster<Void>()
    @ObservationIgnored private let watched = EventBroadcaster<CallApp>()
    @ObservationIgnored private let unwatched = EventBroadcaster<CallApp>()

    init(defaults: UserDefaults = .standard, knownApps: [CallApp] = KnownCallApps.all) {
        self.defaults = defaults
        self.knownApps = knownApps
        // Absent means on.
        state = (defaults.object(forKey: SettingsKey.callDetection) as? Bool ?? true) ? .on : .off
        let stored = defaults.stringArray(forKey: SettingsKey.unwatchedCallApps) ?? []
        unwatchedNames = Set(stored).intersection(knownApps.map(\.name))
    }

    /// Whether the app is watched: every known call app is, until the user turns it off. Detection
    /// being off does not change the choice of an app.
    func isWatched(_ app: CallApp) -> Bool {
        !unwatchedNames.contains(app.name)
    }

    // MARK: Events

    /// `user.TURN_ON_CALL_DETECTION`: Off → On; the choice is saved.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.callDetection)
        state = .on
        turnedOn.emit(())
    }

    /// `user.TURN_OFF_CALL_DETECTION`: On → Off; the choice is saved.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.callDetection)
        state = .off
        turnedOff.emit(())
    }

    /// `user.WATCH_APP`: the app is watched from now on; the choice is saved also while detection
    /// is off. The recorder, told by `watchEvents`, counts the app as started if it already uses
    /// the microphone and detection is on.
    func watch(_ app: CallApp) {
        guard unwatchedNames.contains(app.name) else { return }
        unwatchedNames.remove(app.name)
        saveUnwatched()
        watched.emit(app)
    }

    /// `user.UNWATCH_APP`: the app is no longer watched; the choice is saved also while detection
    /// is off.
    func unwatch(_ app: CallApp) {
        guard knownApps.contains(app), !unwatchedNames.contains(app.name) else { return }
        unwatchedNames.insert(app.name)
        saveUnwatched()
        unwatched.emit(app)
    }

    private func saveUnwatched() {
        // In the order of the table of known apps, so that the stored list does not depend on the
        // order of the clicks.
        defaults.set(knownApps.map(\.name).filter { unwatchedNames.contains($0) }, forKey: SettingsKey.unwatchedCallApps)
    }

    // MARK: Streams

    /// A new stream that yields every time detection is turned on.
    var turnOnEvents: AsyncStream<Void> { turnedOn.stream() }
    /// A new stream that yields every time detection is turned off.
    var turnOffEvents: AsyncStream<Void> { turnedOff.stream() }
    /// A new stream that yields the app every time the user starts watching one.
    var watchEvents: AsyncStream<CallApp> { watched.stream() }
    /// A new stream that yields the app every time the user stops watching one.
    var unwatchEvents: AsyncStream<CallApp> { unwatched.stream() }
}
