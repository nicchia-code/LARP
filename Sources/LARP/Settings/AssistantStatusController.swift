import Foundation
import Observation

/// The `assistant-status` machine: whether omp can be reached on the Mac.
///
/// omp is looked for only while transcript refinement, call summaries or both
/// are on. The two switches live in `UserDefaults` and are off by default; their
/// controllers tell this one when the user turns them on or off.
@MainActor
@Observable
final class AssistantStatusController {
    /// States of the `assistant-status` machine. Every state but `notNeeded` is
    /// inside Needed.
    enum State: Sendable, Equatable {
        case notNeeded
        case checking
        case assistantReady
        case assistantMissing
    }

    /// The controller shared by the app: the settings window and the switches
    /// use the same instance.
    static let shared = AssistantStatusController()

    private(set) var state: State

    /// Refinement, summaries or both are on: omp is looked for.
    var isNeeded: Bool { state != .notNeeded }

    @ObservationIgnored private var refinementOn: Bool
    @ObservationIgnored private var summaryOn: Bool
    @ObservationIgnored private let assistant: any AssistantChecking
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Identifies the latest check; the result of an older one is ignored.
    @ObservationIgnored private var generation = 0

    init(
        defaults: UserDefaults = .standard,
        assistant: any AssistantChecking = OmpAssistantCheck()
    ) {
        self.assistant = assistant
        refinementOn = defaults.bool(forKey: SettingsKey.transcriptRefinement)
        summaryOn = defaults.bool(forKey: SettingsKey.callSummaries)
        state = refinementOn || summaryOn ? .checking : .notNeeded
    }

    // MARK: Events

    /// `macos.APP_LAUNCHED`: Needed → Checking, omp is looked for again. Call once.
    func appLaunched() {
        lookForAssistant()
    }

    /// `user.OPEN_SETTINGS`: Needed → Checking, omp is looked for again.
    func openSettings() {
        lookForAssistant()
    }

    /// `user.TURN_ON_REFINEMENT`: Not needed → Needed, which enters Checking.
    func refinementTurnedOn() {
        refinementOn = true
        turnedOn()
    }

    /// `user.TURN_ON_SUMMARY`: Not needed → Needed, which enters Checking.
    func summaryTurnedOn() {
        summaryOn = true
        turnedOn()
    }

    /// `user.TURN_OFF_REFINEMENT`: Needed → Not needed, only if summaries are off.
    func refinementTurnedOff() {
        refinementOn = false
        turnedOff()
    }

    /// `user.TURN_OFF_SUMMARY`: Needed → Not needed, only if refinement is off.
    func summaryTurnedOff() {
        summaryOn = false
        turnedOff()
    }

    /// Returns when the check in progress has finished.
    func waitUntilIdle() async {
        await task?.value
    }

    // MARK: Machine

    private func turnedOn() {
        guard state == .notNeeded else { return }
        check()
    }

    private func turnedOff() {
        guard state != .notNeeded, !refinementOn, !summaryOn else { return }
        task?.cancel()
        task = nil
        generation += 1
        state = .notNeeded
    }

    private func lookForAssistant() {
        guard state != .notNeeded else { return }
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
