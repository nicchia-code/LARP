import Foundation
import Observation

/// The `call-questions` machine: whether the user may ask omp questions about a call and have its
/// transcript translated by omp.
///
/// The switch lives in `UserDefaults` and is off by default, independently of refinement and
/// summaries, and works whether or not omp can be reached. Whether omp can be reached is the
/// business of `AssistantStatusController`, which is told every time the switch changes. Asking and
/// translating belong to `CallQuestions` and `TranscriptTranslation`, which read `isOn` and listen
/// to `turnOffEvents`.
@MainActor
@Observable
final class CallQuestionsController {
    /// States of the `call-questions` machine.
    enum State: Sendable, Equatable {
        case off
        case on
    }

    /// The controller shared by the app: the settings window and the call page read the same instance.
    static let shared = CallQuestionsController()

    private(set) var state: State

    /// Questions and translations are on: "Chiedi qualcosa a questa call" and "Traduci" are shown.
    var isOn: Bool { state == .on }

    /// `user.TURN_OFF_QUESTIONS`, for the `call-question` and `transcript-translation` machines.
    @ObservationIgnored private let turnedOff = EventBroadcaster<Void>()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let assistantStatus: AssistantStatusController

    init(
        defaults: UserDefaults = .standard,
        assistantStatus: AssistantStatusController = .shared
    ) {
        self.defaults = defaults
        self.assistantStatus = assistantStatus
        state = defaults.bool(forKey: SettingsKey.callQuestions) ? .on : .off
    }

    // MARK: Events

    /// `user.TURN_ON_QUESTIONS`: Off → On.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.callQuestions)
        state = .on
        assistantStatus.questionsTurnedOn()
    }

    /// `user.TURN_OFF_QUESTIONS`: On → Off.
    func turnOff() {
        guard state == .on else { return }
        defaults.set(false, forKey: SettingsKey.callQuestions)
        state = .off
        assistantStatus.questionsTurnedOff()
        turnedOff.emit(())
    }

    /// A new stream that yields every time questions and translations are turned off.
    var turnOffEvents: AsyncStream<Void> {
        turnedOff.stream()
    }
}
