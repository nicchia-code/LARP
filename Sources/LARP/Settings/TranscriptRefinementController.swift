import Foundation
import Observation

/// The `transcript-refinement` machine: whether the transcripts of the calls
/// are refined by omp.
///
/// The switch lives in `UserDefaults` and is off by default. Whether omp can be
/// reached is the business of `AssistantStatusController`, which is told every
/// time the switch changes.
@MainActor
@Observable
final class TranscriptRefinementController {
    /// States of the `transcript-refinement` machine.
    enum State: Sendable, Equatable {
        case off
        case on
    }

    /// The controller shared by the app: the settings window and the call
    /// lifecycle read the same instance.
    static let shared = TranscriptRefinementController()

    private(set) var state: State

    /// Refinement is on: calls are refined, on their own or on request.
    var isOn: Bool { state == .on }

    /// `user.TURN_OFF_REFINEMENT`, for the call machine.
    @ObservationIgnored private let turnedOff = EventBroadcaster<Void>()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let assistantStatus: AssistantStatusController

    init(
        defaults: UserDefaults = .standard,
        assistantStatus: AssistantStatusController = .shared
    ) {
        self.defaults = defaults
        self.assistantStatus = assistantStatus
        state = defaults.bool(forKey: SettingsKey.transcriptRefinement) ? .on : .off
    }

    // MARK: Events

    /// `user.TURN_ON_REFINEMENT`: Off → On.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.transcriptRefinement)
        state = .on
        assistantStatus.refinementTurnedOn()
    }

    /// `user.TURN_OFF_REFINEMENT`: On → Off.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.transcriptRefinement)
        state = .off
        assistantStatus.refinementTurnedOff()
        turnedOff.emit(())
    }

    /// A new stream that yields every time refinement is turned off.
    var turnOffEvents: AsyncStream<Void> {
        turnedOff.stream()
    }
}
