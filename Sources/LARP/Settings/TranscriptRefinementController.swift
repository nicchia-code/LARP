import Foundation
import Observation

/// The `transcript-refinement` machine: whether the transcripts of the calls
/// are refined by omp, and whether omp can be reached on the Mac.
///
/// The switch lives in `UserDefaults` and is off by default. While it is on,
/// the machine looks for omp at every app launch and every time the settings
/// window opens.
@MainActor
@Observable
final class TranscriptRefinementController {
    /// States of the `transcript-refinement` machine. Every state but `off` is
    /// inside On.
    enum State: Sendable, Equatable {
        case off
        case checking
        case assistantReady
        case assistantMissing
    }

    /// The controller shared by the app: the settings window and the call
    /// lifecycle read the same instance.
    static let shared = TranscriptRefinementController()

    private(set) var state: State

    /// Refinement is on: calls are refined, on their own or on request.
    var isOn: Bool { state != .off }

    /// `user.TURN_OFF_REFINEMENT`, for the call machine.
    @ObservationIgnored private let turnedOff = EventBroadcaster<Void>()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let assistant: any AssistantChecking
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Identifies the latest check; the result of an older one is ignored.
    @ObservationIgnored private var generation = 0

    init(
        defaults: UserDefaults = .standard,
        assistant: any AssistantChecking = OmpAssistantCheck()
    ) {
        self.defaults = defaults
        self.assistant = assistant
        state = defaults.bool(forKey: SettingsKey.transcriptRefinement) ? .checking : .off
    }

    // MARK: Events

    /// `macos.APP_LAUNCHED`: On → Checking, omp is looked for again. Call once.
    func appLaunched() {
        lookForAssistant()
    }

    /// `user.OPEN_SETTINGS`: On → Checking, omp is looked for again.
    func openSettings() {
        lookForAssistant()
    }

    /// `user.TURN_ON_REFINEMENT`: Off → On, which enters Checking.
    func turnOn() {
        guard state == .off else { return }
        defaults.set(true, forKey: SettingsKey.transcriptRefinement)
        check()
    }

    /// `user.TURN_OFF_REFINEMENT`: On → Off.
    func turnOff() {
        guard state != .off else { return }
        defaults.set(false, forKey: SettingsKey.transcriptRefinement)
        task?.cancel()
        task = nil
        generation += 1
        state = .off
        turnedOff.emit(())
    }

    /// A new stream that yields every time refinement is turned off.
    var turnOffEvents: AsyncStream<Void> {
        turnedOff.stream()
    }

    /// Returns when the check in progress has finished.
    func waitUntilIdle() async {
        await task?.value
    }

    // MARK: Machine

    private func lookForAssistant() {
        guard state != .off else { return }
        check()
    }

    /// Enters Checking: omp is searched and asked to answer.
    private func check() {
        task?.cancel()
        generation += 1
        let current = generation
        state = .checking
        let assistant = assistant
        task = Task { [weak self] in
            let reached = await assistant.check()
            self?.finishCheck(reached: reached, generation: current)
        }
    }

    /// `assistant.REACHED` → Assistant ready; `assistant.UNREACHABLE` →
    /// Assistant missing.
    private func finishCheck(reached: Bool, generation current: Int) {
        guard current == generation else { return }
        state = reached ? .assistantReady : .assistantMissing
    }
}
