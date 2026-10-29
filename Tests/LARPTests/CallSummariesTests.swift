import Foundation
import Testing

@testable import LARP

/// An assistant check that always answers the same.
private struct ReachableAssistant: AssistantChecking {
    func check() async -> Bool { true }
}

/// The summaries machine and the others on the same defaults, as the app wires them.
@MainActor
private struct Machines {
    let defaults: UserDefaults
    let status: AssistantStatusController
    let summaries: CallSummariesController
    let refinement: TranscriptRefinementController

    init(summaryStored: Bool = false, refinementStored: Bool = false) {
        let defaults = UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
        defaults.set(summaryStored, forKey: SettingsKey.callSummaries)
        defaults.set(refinementStored, forKey: SettingsKey.transcriptRefinement)
        self.defaults = defaults
        status = AssistantStatusController(defaults: defaults, assistant: ReachableAssistant())
        summaries = CallSummariesController(defaults: defaults, assistantStatus: status)
        refinement = TranscriptRefinementController(defaults: defaults, assistantStatus: status)
    }
}

@Suite("CallSummaries machine", .serialized)
@MainActor
struct CallSummariesMachineTests {
    @Test("summaries are off by default")
    func offByDefault() {
        let machines = Machines()
        #expect(machines.summaries.state == .off)
        #expect(machines.summaries.isOn == false)
        #expect(machines.defaults.bool(forKey: SettingsKey.callSummaries) == false)
    }

    @Test("turning on goes to On, is stored and makes omp needed")
    func turnOn() async {
        let machines = Machines()
        machines.summaries.turnOn()
        #expect(machines.summaries.state == .on)
        #expect(machines.summaries.isOn)
        #expect(machines.defaults.bool(forKey: SettingsKey.callSummaries))
        #expect(machines.status.isNeeded)
        await machines.status.waitUntilIdle()
        #expect(machines.status.state == .assistantReady)
    }

    @Test("turning off goes to Off, is stored and signals the call-summary machine")
    func turnOff() async {
        let machines = Machines(summaryStored: true)
        let events = machines.summaries.turnOffEvents
        machines.summaries.turnOff()
        #expect(machines.summaries.state == .off)
        #expect(machines.defaults.bool(forKey: SettingsKey.callSummaries) == false)
        #expect(machines.status.state == .notNeeded)
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() != nil)
    }

    @Test("a stored switch is on at the next launch")
    func storedSwitchIsRestored() {
        #expect(Machines(summaryStored: true).summaries.state == .on)
    }

    @Test("turning on while already on does nothing")
    func turnOnTwice() async {
        let machines = Machines()
        machines.summaries.turnOn()
        await machines.status.waitUntilIdle()
        machines.summaries.turnOn()
        #expect(machines.status.state == .assistantReady)
    }

    @Test("turning off while already off leaves the stored value off")
    func turnOffTwice() {
        let machines = Machines()
        machines.summaries.turnOff()
        #expect(machines.summaries.state == .off)
        #expect(machines.defaults.bool(forKey: SettingsKey.callSummaries) == false)
    }

    @Test("summaries and refinement are independent")
    func independentOfRefinement() async {
        let machines = Machines(refinementStored: true)
        #expect(machines.summaries.state == .off)
        machines.summaries.turnOn()
        #expect(machines.refinement.state == .on)
        machines.summaries.turnOff()
        #expect(machines.refinement.state == .on)
        #expect(machines.defaults.bool(forKey: SettingsKey.transcriptRefinement))
        // omp is still needed by refinement.
        #expect(machines.status.isNeeded)
        machines.refinement.turnOff()
        machines.summaries.turnOn()
        machines.refinement.turnOn()
        #expect(machines.summaries.state == .on)
        machines.refinement.turnOff()
        #expect(machines.summaries.state == .on)
        #expect(machines.status.isNeeded)
        await machines.status.waitUntilIdle()
    }
}
