import Foundation
import SwiftData
import Testing

@testable import LARP

/// The store as it was saved by the version whose summaries had decisions as texts and next steps:
/// only what the summary needs.
private enum PreviousStore {
    @Model
    final class Call {
        @Attribute(.unique) var id: UUID
        var title: String?
        var startedAt: Date
        var endedAt: Date?
        var duration: TimeInterval
        var callAppName: String?
        var transcriptionLanguage: String
        var stateRawValue: String
        var micAudioPath: String
        var systemAudioPath: String
        var summaryStateRawValue: String = "none"

        @Relationship(deleteRule: .cascade, inverse: \TranscriptLine.call)
        var lines: [TranscriptLine] = []

        @Relationship(deleteRule: .cascade, inverse: \Participant.call)
        var participants: [Participant] = []

        @Relationship(deleteRule: .cascade, inverse: \CallSummary.call)
        var summary: CallSummary?

        init(id: UUID) {
            self.id = id
            self.startedAt = .now
            self.duration = 60
            self.transcriptionLanguage = "it-IT"
            self.stateRawValue = "ready"
            self.micAudioPath = "Recordings/\(id.uuidString)/mic.caf"
            self.systemAudioPath = "Recordings/\(id.uuidString)/system.caf"
        }
    }

    @Model
    final class TranscriptLine {
        var speakerKindRawValue: String
        var participant: Participant?
        var start: TimeInterval
        var end: TimeInterval
        var text: String
        var call: Call?
        var originalText: String?
        var originalSpeakerKindRawValue: String?
        var originalParticipantNumber: Int?

        init(text: String) {
            self.speakerKindRawValue = "me"
            self.start = 0
            self.end = 1
            self.text = text
        }
    }

    @Model
    final class Participant {
        var number: Int
        var name: String?
        var call: Call?

        @Relationship(deleteRule: .nullify, inverse: \TranscriptLine.participant)
        var lines: [TranscriptLine] = []

        init(number: Int) {
            self.number = number
        }
    }

    @Model
    final class CallSummary {
        var keyConcepts: [String]
        var decisions: [String]
        var nextSteps: [SummaryNextStep]
        var text: String
        var language: String
        var writtenAt: Date
        var call: Call?

        init() {
            keyConcepts = ["Budget"]
            decisions = ["Si parte a marzo", "Assumere due persone"]
            nextSteps = [SummaryNextStep(text: "Inviare il piano", owner: "Io"), SummaryNextStep(text: "Prenotare la sala")]
            text = "Resto"
            language = "it-IT"
            writtenAt = Date(timeIntervalSince1970: 1_700_000_000)
        }
    }

    static let schema = Schema([Call.self, TranscriptLine.self, Participant.self, CallSummary.self])
}

@Suite("Summary structure storage", .serialized)
@MainActor
struct SummaryStructureStorageTests {
    @Test("a summary keeps every field of the structure, in order")
    func storesStructure() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let writtenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.summary = CallSummary(
            opening: "Si parte a marzo.",
            openingHighlight: "marzo",
            keyConcepts: ["Budget", "Scadenze"],
            decisionItems: [SummaryDecision(text: "Parte", lineStart: 12.5), SummaryDecision(text: "Assumere")],
            actionItems: [
                SummaryActionItem(text: "Inviare il piano", owner: "Io", due: "venerdì"),
                SummaryActionItem(text: "Prenotare la sala", owner: "Partecipante 2", isDone: true),
                SummaryActionItem(text: "Rivedere il contratto"),
            ],
            openQuestions: ["Chi paga?"],
            text: "Resto",
            language: "en-US",
            writtenAt: writtenAt)
        context.insert(call)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Call>()).first?.summary)
        #expect(stored.opening == "Si parte a marzo.")
        #expect(stored.openingHighlight == "marzo")
        #expect(stored.keyConcepts == ["Budget", "Scadenze"])
        #expect(stored.decisionItems.map(\.text) == ["Parte", "Assumere"])
        #expect(stored.decisionItems.map(\.lineStart) == [12.5, nil])
        #expect(stored.actionItems.map(\.text) == ["Inviare il piano", "Prenotare la sala", "Rivedere il contratto"])
        #expect(stored.actionItems.map(\.owner) == ["Io", "Partecipante 2", nil])
        #expect(stored.actionItems.map(\.due) == ["venerdì", nil, nil])
        #expect(stored.actionItems.map(\.isDone) == [false, true, false])
        #expect(stored.openQuestions == ["Chi paga?"])
        #expect(stored.text == "Resto")
        #expect(stored.language == "en-US")
        #expect(stored.writtenAt == writtenAt)
    }

    @Test("an action is not done by default and an opening is empty by default")
    func defaults() {
        let summary = CallSummary(actionItems: [SummaryActionItem(text: "A")], language: "it-IT")
        #expect(summary.actionItems.map(\.isDone) == [false])
        #expect(summary.opening == "")
        #expect(summary.openingHighlight == "")
        #expect(summary.openQuestions.isEmpty)
        #expect(summary.decisionItems.isEmpty)
    }

    @Test("a store saved before this structure opens: next steps are actions without due and not done")
    func previousStoreOpens() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "LARPTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "LARP.store")
        let callID = UUID()

        do {
            let previous = try ModelContainer(
                for: PreviousStore.schema,
                configurations: [ModelConfiguration(schema: PreviousStore.schema, url: storeURL)]
            )
            let call = PreviousStore.Call(id: callID)
            call.summaryStateRawValue = "written"
            call.summary = PreviousStore.CallSummary()
            previous.mainContext.insert(call)
            try previous.mainContext.save()
        }

        let container = try ModelContainer(
            for: ArchiveStore.schema,
            configurations: [ModelConfiguration(schema: ArchiveStore.schema, url: storeURL)]
        )
        let context = container.mainContext
        let call = try #require(try context.fetch(FetchDescriptor<Call>()).first)
        #expect(call.id == callID)
        #expect(call.summaryState == .written)
        let summary = try #require(call.summary)
        #expect(summary.keyConcepts == ["Budget"])
        #expect(summary.text == "Resto")
        #expect(summary.language == "it-IT")
        #expect(summary.writtenAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(summary.opening == "")
        #expect(summary.openingHighlight == "")
        #expect(summary.openQuestions.isEmpty)
        #expect(summary.decisionItems == [SummaryDecision(text: "Si parte a marzo"), SummaryDecision(text: "Assumere due persone")])
        #expect(
            summary.actionItems == [
                SummaryActionItem(text: "Inviare il piano", owner: "Io"),
                SummaryActionItem(text: "Prenotare la sala"),
            ])
        #expect(summary.actionItems.allSatisfy { $0.due == nil && !$0.isDone })

        // Ticking an action of such a summary is saved, and the rest stays as it was.
        var actions = summary.actionItems
        actions[1].isDone = true
        summary.actionItems = actions
        try context.save()
        let reread = try #require(try context.fetch(FetchDescriptor<CallSummary>()).first)
        #expect(reread.actionItems.map(\.isDone) == [false, true])
        #expect(reread.actionItems.map(\.text) == ["Inviare il piano", "Prenotare la sala"])
        #expect(reread.decisionItems.map(\.text) == ["Si parte a marzo", "Assumere due persone"])
    }
}

@Suite("Summary language")
@MainActor
struct SummaryLanguageTests {
    private func defaults() -> UserDefaults {
        let suite = "LARPTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("the choice is \"Come la call\" unless another one was saved")
    func defaultChoice() {
        #expect(SummaryLanguageController(defaults: defaults()).choice == .sameAsCall)
    }

    @Test("an unknown stored value reads as \"Come la call\"")
    func unknownValue() {
        let defaults = defaults()
        defaults.set("fr-FR", forKey: SettingsKey.summaryLanguage)
        #expect(SummaryLanguageController(defaults: defaults).choice == .sameAsCall)
    }

    @Test("a choice is saved and read back by a new controller")
    func choiceIsSaved() {
        let defaults = defaults()
        let controller = SummaryLanguageController(defaults: defaults)
        controller.choose(.english)
        #expect(controller.choice == .english)
        #expect(defaults.string(forKey: SettingsKey.summaryLanguage) == "en-US")
        #expect(SummaryLanguageController(defaults: defaults).choice == .english)
        controller.choose(.italian)
        #expect(defaults.string(forKey: SettingsKey.summaryLanguage) == "it-IT")
        controller.choose(.sameAsCall)
        #expect(defaults.string(forKey: SettingsKey.summaryLanguage) == "call")
        #expect(SummaryLanguageController(defaults: defaults).choice == .sameAsCall)
    }

    @Test("\"Come la call\" follows the call, the other two ignore it")
    func languageAsked() {
        #expect(SummaryLanguageChoice.sameAsCall.language(forCallLanguage: "en-US") == "en-US")
        #expect(SummaryLanguageChoice.sameAsCall.language(forCallLanguage: "it-IT") == "it-IT")
        #expect(SummaryLanguageChoice.italian.language(forCallLanguage: "en-US") == "it-IT")
        #expect(SummaryLanguageChoice.english.language(forCallLanguage: "it-IT") == "en-US")
    }
}

private let structuredAnswer = """
    {"opening": "Si parte.", "openingHighlight": "Si parte", "keyConcepts": [], "decisions": [], \
    "actionItems": [{"text": "Inviare il piano", "owner": "Io", "due": "venerdì"}, {"text": "Chiamare"}], \
    "openQuestions": [], "other": ""}
    """

@Suite("Summary of a call: language and ticks", .serialized)
@MainActor
struct SummaryLanguageAndTicksTests {
    private func summarisableCall(_ harness: CallHarness, language: String = "it-IT") throws -> Call {
        let call = try harness.insertCall(.ready, title: "Riunione", language: language)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno"))
        try harness.context.save()
        return call
    }

    @Test("the language asked is stored with the summary; a new choice applies to the summaries written after it")
    func languageStoredWithSummary() async throws {
        let summarizer = FakeSummarizer(.answer(structuredAnswer))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true, summaryLanguage: .english)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .written })
        #expect(call.summary?.language == "en-US")
        #expect(try #require(summarizer.prompts.first).contains("in inglese"))

        // While the new one is being written the earlier summary keeps its language.
        harness.summaryLanguage.choice = .italian
        #expect(call.summary?.language == "en-US")
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summary?.language == "it-IT" })
        #expect(try #require(summarizer.prompts.last).contains("in italiano"))
    }

    @Test("\"Come la call\" asks the language of the call")
    func sameAsCall() async throws {
        let summarizer = FakeSummarizer(.answer(structuredAnswer))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true, summaryLanguage: .sameAsCall)
        defer { harness.cleanUp() }
        let english = try summarisableCall(harness, language: "en-US")
        let italian = try summarisableCall(harness, language: "it-IT")

        harness.lifecycle.summarize(english)
        harness.lifecycle.summarize(italian)
        #expect(await harness.eventually { english.summaryState == .written && italian.summaryState == .written })
        #expect(english.summary?.language == "en-US")
        #expect(italian.summary?.language == "it-IT")
    }

    @Test("ticking an action marks it done, or not done again, saves it and leaves the state of the summary")
    func ticking() async throws {
        let harness = try CallHarness(summarizer: FakeSummarizer(.answer(structuredAnswer)), summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .written })
        #expect(call.summary?.actionItems.map(\.isDone) == [false, false])

        harness.lifecycle.toggleActionItem(of: call, at: 1)
        #expect(call.summary?.actionItems.map(\.isDone) == [false, true])
        #expect(call.summaryState == .written)
        let stored = try #require(try harness.context.fetch(FetchDescriptor<CallSummary>()).first)
        #expect(stored.actionItems.map(\.isDone) == [false, true])
        #expect(stored.actionItems.map(\.text) == ["Inviare il piano", "Chiamare"])
        #expect(stored.actionItems.map(\.due) == ["venerdì", nil])

        harness.lifecycle.toggleActionItem(of: call, at: 1)
        #expect(call.summary?.actionItems.map(\.isDone) == [false, false])

        // Not an action of this summary: nothing changes.
        harness.lifecycle.toggleActionItem(of: call, at: 2)
        harness.lifecycle.toggleActionItem(of: call, at: -1)
        #expect(call.summary?.actionItems.map(\.isDone) == [false, false])
    }

    @Test("a call without summary has no action to tick")
    func tickingWithoutSummary() throws {
        let harness = try CallHarness(summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        harness.lifecycle.toggleActionItem(of: call, at: 0)
        #expect(call.summary == nil)
        #expect(call.summaryState == .none)
    }

    @Test("a new summary replaces the earlier one and every action starts not done")
    func ticksAreLostOnRegeneration() async throws {
        let summarizer = FakeSummarizer(.answer(structuredAnswer))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .written })
        harness.lifecycle.toggleActionItem(of: call, at: 0)
        harness.lifecycle.toggleActionItem(of: call, at: 1)
        #expect(call.summary?.actionItems.map(\.isDone) == [true, true])

        harness.lifecycle.summarize(call)
        #expect(call.summaryState == .writing)
        #expect(call.summary?.actionItems.map(\.isDone) == [true, true])
        #expect(await harness.eventually { call.summaryState == .written })

        #expect(call.summary?.actionItems.map(\.isDone) == [false, false])
        #expect(try harness.context.fetch(FetchDescriptor<CallSummary>()).count == 1)
    }
}
