import Foundation
import Observation

/// The `call-summaries` machine: whether the calls are summarised by omp.
///
/// The switch lives in `UserDefaults` and is off by default, independently of
/// transcript refinement. Whether omp can be reached is the business of
/// `AssistantStatusController`, which is told every time the switch changes.
/// Starting and stopping the summary of each call belongs to the `call-summary`
/// machine, which reads `isOn` and listens to `turnOffEvents`.
@MainActor
@Observable
final class CallSummariesController {
    /// States of the `call-summaries` machine.
    enum State: Sendable, Equatable {
        case off
        case on
    }

    /// The controller shared by the app: the settings window and the call
    /// lifecycle read the same instance.
    static let shared = CallSummariesController()

    private(set) var state: State

    /// Summaries are on: new calls are summarised on their own and any call
    /// whose participants have been told apart can be summarised on request.
    var isOn: Bool { state == .on }

    /// `user.TURN_OFF_SUMMARY`, for the `call-summary` machine.
    @ObservationIgnored private let turnedOff = EventBroadcaster<Void>()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let assistantStatus: AssistantStatusController

    init(
        defaults: UserDefaults = .standard,
        assistantStatus: AssistantStatusController = .shared
    ) {
        self.defaults = defaults
        self.assistantStatus = assistantStatus
        state = defaults.bool(forKey: SettingsKey.callSummaries) ? .on : .off
    }

    // MARK: Events

    /// `user.TURN_ON_SUMMARY`: Off → On.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.callSummaries)
        state = .on
        assistantStatus.summaryTurnedOn()
    }

    /// `user.TURN_OFF_SUMMARY`: On → Off.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.callSummaries)
        state = .off
        assistantStatus.summaryTurnedOff()
        turnedOff.emit(())
    }

    /// A new stream that yields every time summaries are turned off.
    var turnOffEvents: AsyncStream<Void> {
        turnedOff.stream()
    }
}
