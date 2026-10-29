import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

/// A call with a line of "Io" and lines of two participants, one of them renamed by the user.
@MainActor
private func addLines(to call: Call) {
    let anna = Participant(number: 1, name: "Anna Rossi")
    let two = Participant(number: 2)
    call.participants.append(anna)
    call.participants.append(two)
    call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno a tutti"))
    call.lines.append(TranscriptLine(speakerKind: .participant, participant: anna, start: 2.5, end: 4, text: "Il meeting e' alle tre"))
    call.lines.append(TranscriptLine(speakerKind: .participant, participant: two, start: 5, end: 7, text: "Va bene"))
}

private let validSummary = """
    {"keyConcepts": ["Budget"], "decisions": ["Si parte a marzo"], \
    "nextSteps": [{"text": "Inviare il piano", "owner": "Partecipante 1"}, {"text": "Chiamare il fornitore"}], \
    "other": "Una nota"}
    """

private let otherSummary = """
    {"keyConcepts": [], "decisions": [], "nextSteps": [], "other": ""}
    """

@Suite("call-summary machine")
struct SummaryTransitionTests {
    private func target(_ state: SummaryState, _ event: SummaryEvent) -> SummaryState? {
        CallSummaryStateMachine.target(from: state, on: event)
    }

    @Test("No summary → Summarising only with summaries on and at least one line")
    func noSummary() {
        #expect(target(.none, .participantsSeparated(summariesOn: true, hasLines: true)) == .writing)
        #expect(target(.none, .participantsSeparated(summariesOn: false, hasLines: true)) == nil)
        #expect(target(.none, .participantsSeparated(summariesOn: true, hasLines: false)) == nil)
        #expect(target(.none, .summarizeCall(summariesOn: true, hasLines: true, participantsTold: true)) == .writing)
        #expect(target(.none, .summarizeCall(summariesOn: false, hasLines: true, participantsTold: true)) == nil)
        #expect(target(.none, .summarizeCall(summariesOn: true, hasLines: false, participantsTold: true)) == nil)
        #expect(target(.none, .summarizeCall(summariesOn: true, hasLines: true, participantsTold: false)) == nil)
        #expect(target(.none, .turnOffSummary(hadSummary: false)) == nil)
        #expect(target(.none, .appLaunched) == nil)
        #expect(target(.none, .networkAvailable) == nil)
    }

    @Test("Summarising")
    func writing() {
        #expect(target(.writing, .summaryWritten) == .written)
        #expect(target(.writing, .summaryFailed) == .awaitingRetry)
        #expect(target(.writing, .turnOffSummary(hadSummary: false)) == SummaryState.none)
        #expect(target(.writing, .turnOffSummary(hadSummary: true)) == .written)
        #expect(target(.writing, .appLaunched) == .writing)
        #expect(target(.writing, .summarizeCall(summariesOn: true, hasLines: true, participantsTold: true)) == nil)
        #expect(target(.writing, .networkAvailable) == nil)
    }

    @Test("Awaiting summary retry")
    func awaitingRetry() {
        #expect(target(.awaitingRetry, .networkAvailable) == .writing)
        #expect(target(.awaitingRetry, .appLaunched) == .writing)
        #expect(target(.awaitingRetry, .summarizeCall(summariesOn: true, hasLines: true, participantsTold: true)) == .writing)
        #expect(target(.awaitingRetry, .summarizeCall(summariesOn: true, hasLines: false, participantsTold: true)) == nil)
        #expect(target(.awaitingRetry, .turnOffSummary(hadSummary: false)) == SummaryState.none)
        #expect(target(.awaitingRetry, .turnOffSummary(hadSummary: true)) == .written)
        #expect(target(.awaitingRetry, .summaryWritten) == nil)
    }

    @Test("Summarised → Summarising only with summaries on")
    func written() {
        #expect(target(.written, .summarizeCall(summariesOn: true, hasLines: true, participantsTold: true)) == .writing)
        #expect(target(.written, .summarizeCall(summariesOn: false, hasLines: true, participantsTold: true)) == nil)
        #expect(target(.written, .participantsSeparated(summariesOn: true, hasLines: true)) == nil)
        #expect(target(.written, .appLaunched) == nil)
        #expect(target(.written, .networkAvailable) == nil)
        #expect(target(.written, .turnOffSummary(hadSummary: true)) == nil)
    }
}

@Suite("SummaryRequest")
@MainActor
struct SummaryRequestTests {
    private func makeCall(language: String = "it-IT") -> Call {
        let call = Call(
            title: "Riunione segreta", callAppName: "Zoom", transcriptionLanguage: language, state: .ready)
        addLines(to: call)
        return call
    }

    @Test("sends numbered lines in order of start with original speakers and times, as JSON after fixed instructions")
    func prompt() throws {
        let call = makeCall()
        // Lines added out of order are still numbered by start time.
        call.lines.append(TranscriptLine(speakerKind: .me, start: 1, end: 2.25, text: "Una \"riga\" con / barra"))

        let prompt = try #require(SummaryRequest(call: call)).prompt

        #expect(prompt.hasPrefix(SummaryRequest.instructions(language: "it-IT")))
        let json = try #require(prompt.range(of: "\n\n[\n").map { String(prompt[$0.lowerBound...]) })
        let rows = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        #expect(rows.map { $0["number"] as? Int } == [1, 2, 3, 4])
        #expect(rows.map { $0["speaker"] as? String } == ["Io", "Io", "Partecipante 1", "Partecipante 2"])
        #expect(rows.map { $0["start"] as? Double } == [0, 1, 2.5, 5])
        #expect(rows.map { $0["end"] as? Double } == [2, 2.25, 4, 7])
        #expect(rows[1]["text"] as? String == "Una \"riga\" con / barra")
        #expect(rows.allSatisfy { Set($0.keys) == ["number", "speaker", "start", "end", "text"] })
    }

    @Test("never sends the title, the names given by the user, the dates or the app of the call")
    func sendsNothingElse() throws {
        let call = makeCall()
        let prompt = try #require(SummaryRequest(call: call)).prompt
        for secret in ["Riunione segreta", "Anna", "Rossi", "Zoom", String(Calendar.current.component(.year, from: call.startedAt))] {
            #expect(!prompt.contains(secret), "\(secret)")
        }
    }

    @Test("the instructions tell where the lines come from, who the participants are and what to answer")
    func instructions() {
        let text = SummaryRequest.instructions(language: "it-IT")
        for part in [
            "riconoscimento vocale automatico", "separazione automatica", "senza segnalare",
            "Io", "Partecipante <numero>", "senza indovinare nomi",
            "keyConcepts", "decisions", "nextSteps", "owner", "other",
        ] {
            #expect(text.contains(part), "\(part)")
        }
    }

    @Test("the summary is asked in the transcription language of the call")
    func language() {
        #expect(SummaryRequest.instructions(language: "it-IT").contains("in italiano"))
        #expect(SummaryRequest.instructions(language: "en-US").contains("in inglese"))
        #expect(SummaryRequest(call: makeCall(language: "en-US"))?.language == "en-US")
    }

    @Test("a refined call is sent with its original text and speakers")
    func originalsAreSent() throws {
        let call = makeCall()
        let lines = call.sortedLines
        lines[1].originalText = "Il meeting e' alle tre"
        lines[1].originalSpeakerKind = .participant
        lines[1].originalParticipantNumber = 2
        lines[1].text = "Corretto"
        lines[1].participant = call.participants.first { $0.number == 1 }

        let request = try #require(SummaryRequest(call: call))

        #expect(request.lines[1].speaker == .participant(2))
        #expect(request.lines[1].text == "Il meeting e' alle tre")
    }

    @Test("a line of the others without participant is never sent: there is no request")
    func lineWithoutParticipantIsNotSent() {
        let call = makeCall()
        call.sortedLines[1].speakerKind = .others
        call.sortedLines[1].participant = nil

        #expect(SummaryRequest(call: call) == nil)
    }

    @Test("a complete answer is a summary, also inside a code block")
    func validAnswers() {
        let summary = SummaryRequest.summary(from: "```json\n" + validSummary + "\n```", participants: [1, 2])
        #expect(summary?.keyConcepts == ["Budget"])
        #expect(summary?.decisions == ["Si parte a marzo"])
        #expect(
            summary?.nextSteps == [
                SummaryNextStep(text: "Inviare il piano", owner: "Partecipante 1"),
                SummaryNextStep(text: "Chiamare il fornitore"),
            ])
        #expect(summary?.text == "Una nota")
        #expect(SummaryRequest.summary(from: otherSummary, participants: [])?.nextSteps == [])
        #expect(
            SummaryRequest.summary(
                from: #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"text": "Io lo faccio", "owner": "Io"}], "other": ""}"#,
                participants: [])?.nextSteps == [SummaryNextStep(text: "Io lo faccio", owner: "Io")])
    }

    @Test(
        "an answer that is not a complete summary, or names an owner who is not in the call, is not valid",
        arguments: [
            "non è JSON",
            "{}",
            "[]",
            // a field missing
            #"{"keyConcepts": [], "decisions": [], "nextSteps": []}"#,
            #"{"keyConcepts": [], "decisions": [], "other": ""}"#,
            // a field of the wrong type
            #"{"keyConcepts": "Budget", "decisions": [], "nextSteps": [], "other": ""}"#,
            #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"owner": "Io"}], "other": ""}"#,
            // an owner who is not in the call, a name, or something else than a participant
            #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"text": "A", "owner": "Partecipante 3"}], "other": ""}"#,
            #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"text": "A", "owner": "Anna"}], "other": ""}"#,
            #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"text": "A", "owner": "Altri"}], "other": ""}"#,
        ])
    func invalidAnswers(text: String) {
        #expect(SummaryRequest.summary(from: text, participants: [1, 2]) == nil)
    }
}

@Suite("call summary", .serialized)
@MainActor
struct CallSummaryTests {
    private func summarisableCall(_ harness: CallHarness, _ state: CallState = .ready) throws -> Call {
        let call = try harness.insertCall(state, title: "Riunione")
        addLines(to: call)
        try harness.context.save()
        return call
    }

    private func summaries(_ harness: CallHarness) throws -> [CallSummary] {
        try harness.context.fetch(FetchDescriptor<CallSummary>())
    }

    @Test("participants separated with summaries on: the summary starts on its own and is saved")
    func summarisesAfterSeparation() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(separator: FakeSeparator(.succeed), summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.summaryState == .written })

        #expect(call.state == .ready)
        #expect(summarizer.prompts.count == 1)
        let summary = try #require(call.summary)
        #expect(summary.keyConcepts == ["Budget"])
        #expect(summary.decisions == ["Si parte a marzo"])
        #expect(summary.nextSteps.map(\.owner) == ["Partecipante 1", nil])
        #expect(summary.text == "Una nota")
        #expect(summary.language == "it-IT")
        #expect(try summaries(harness).count == 1)
    }

    @Test("with summaries off the assistant is never asked and the call has no summary")
    func summariesOffSkipThem() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(separator: FakeSeparator(.succeed), summarizer: summarizer, summariesOn: false)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.state == .ready })
        await harness.lifecycle.waitUntilSummaryIdle()

        #expect(summarizer.prompts.isEmpty)
        #expect(call.summaryState == .none)
        #expect(call.summary == nil)
    }

    @Test("a call without lines never goes to Summarising")
    func noLines() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(separator: FakeSeparator(.succeed), summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.state == .ready })

        #expect(call.summaryState == .none)
        #expect(!harness.lifecycle.canSummarize(call))
        harness.lifecycle.summarize(call)
        #expect(call.summaryState == .none)
        #expect(summarizer.prompts.isEmpty)
    }

    @Test("the summary starts alongside the refinement and does not wait for it")
    func independentOfRefinement() async throws {
        let gate = WorkGate()
        let refiner = FakeSummarizer(.held(gate, answer: nil))
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(
            separator: FakeSeparator(.succeed), refiner: refiner, refinementOn: true,
            summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.summaryState == .written })

        // The refinement has not ended: the summary did not wait for it.
        #expect(call.state == .refiningTranscript)
        #expect(refiner.prompts.count == 1)
        #expect(summarizer.prompts.count == 1)

        // The failure of the refinement does not touch the summary.
        gate.open()
        await harness.lifecycle.waitUntilRefinementIdle()
        #expect(call.state == .awaitingRefinementRetry)
        #expect(call.summaryState == .written)
        #expect(call.summary != nil)
    }

    @Test("the failure of the summary does not stop the refinement")
    func summaryFailureLeavesRefinement() async throws {
        let refiner = FakeSummarizer(
            .answer(#"[{"number": 1, "text": "Ciao", "speaker": "Io"}, {"number": 2, "text": "A", "speaker": "Partecipante 1"}, {"number": 3, "text": "B", "speaker": "Partecipante 2"}]"#))
        let harness = try CallHarness(
            separator: FakeSeparator(.succeed), refiner: refiner, refinementOn: true,
            summarizer: FakeSummarizer(.fail), summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.state == .ready && call.summaryState == .awaitingRetry })

        #expect(call.isRefined)
        #expect(call.summary == nil)
    }

    @Test("a summary is written from the original lines also after the transcript was refined")
    func summaryFromOriginals() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        let line = call.sortedLines[1]
        line.originalText = line.text
        line.originalSpeakerKind = .participant
        line.originalParticipantNumber = 1
        line.text = "Testo rifinito"

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .written })

        let prompt = try #require(summarizer.prompts.first)
        #expect(prompt.contains("Il meeting e' alle tre"))
        #expect(!prompt.contains("Testo rifinito"))
    }

    @Test(
        "an answer that is not valid saves nothing and the call awaits a retry",
        arguments: ["niente JSON", "{}", #"{"keyConcepts": [], "decisions": [], "nextSteps": [{"text": "A", "owner": "Partecipante 7"}], "other": ""}"#])
    func invalidAnswerFails(text: String) async throws {
        let harness = try CallHarness(summarizer: FakeSummarizer(.answer(text)), summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .awaitingRetry })

        #expect(call.summary == nil)
        #expect(try summaries(harness).isEmpty)
        #expect(harness.lifecycle.statusLabel(of: call) == "Sintesi da fare")
    }

    @Test("an assistant that cannot be reached makes the summary fail and the earlier summary stays")
    func unreachableAssistantFails() async throws {
        let harness = try CallHarness(summarizer: FakeSummarizer(.fail), summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        call.summary = CallSummary(text: "Prima", language: "it-IT")
        call.summaryState = .written
        try harness.context.save()

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .awaitingRetry })

        #expect(call.summary?.text == "Prima")
        #expect(try summaries(harness).count == 1)
    }

    @Test("the network coming back and a new launch of the app try a failed summary again; so does the user")
    func retries() async throws {
        let summarizer = FakeSummarizer(.fail)
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .awaitingRetry })

        // The network comes back and the assistant answers.
        summarizer.setBehavior(.answer(validSummary))
        harness.lifecycle.networkAvailable()
        #expect(await harness.eventually { call.summaryState == .written })
        #expect(summarizer.prompts.count == 2)

        // A new failure, then the app is launched again.
        summarizer.setBehavior(.fail)
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .awaitingRetry })
        summarizer.setBehavior(.answer(validSummary))
        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { call.summaryState == .written })

        // Again, and this time the user asks.
        summarizer.setBehavior(.fail)
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .awaitingRetry })
        summarizer.setBehavior(.answer(validSummary))
        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { call.summaryState == .written })
        #expect(try summaries(harness).count == 1)
    }

    @Test("a summary found while it was being written when the app launches starts again")
    func launchRestartsWriting() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        call.summaryState = .writing
        try harness.context.save()

        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { call.summaryState == .written })

        #expect(summarizer.prompts.count == 1)
    }

    @Test("a summary written again replaces the earlier one in the store")
    func replacesSummary() async throws {
        let summarizer = FakeSummarizer(.answer(validSummary))
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        call.summary = CallSummary(text: "Prima", language: "it-IT")
        call.summaryState = .written
        try harness.context.save()

        #expect(harness.lifecycle.canSummarize(call))
        harness.lifecycle.summarize(call)
        #expect(call.summaryState == .writing)
        #expect(call.summary?.text == "Prima")
        #expect(await harness.eventually { call.summary?.text == "Una nota" })

        #expect(call.summaryState == .written)
        #expect(try summaries(harness).count == 1)
    }

    @Test("summarising on request needs summaries on, lines and the participants told apart")
    func canSummarize() throws {
        let harness = try CallHarness(summarizer: FakeSummarizer(.fail), summariesOn: true)
        defer { harness.cleanUp() }

        // An old call: ready, no summary.
        let ready = try summarisableCall(harness)
        #expect(harness.lifecycle.canSummarize(ready))

        // Participants not told apart yet.
        for state in [CallState.recording, .awaitingLanguage, .transcribing, .separatingParticipants, .awaitingSeparationRetry] {
            let call = try summarisableCall(harness, state)
            #expect(!harness.lifecycle.canSummarize(call), "\(state)")
        }
        for state in [CallState.refiningTranscript, .awaitingRefinementRetry] {
            let call = try summarisableCall(harness, state)
            #expect(harness.lifecycle.canSummarize(call), "\(state)")
        }

        harness.summaries.isOn = false
        #expect(!harness.lifecycle.canSummarize(ready))
        // A summary already waiting to be tried again can be tried at once.
        ready.summaryState = .awaitingRetry
        #expect(harness.lifecycle.canSummarize(ready))
        // A summary being written cannot be asked again.
        ready.summaryState = .writing
        #expect(!harness.lifecycle.canSummarize(ready))
        // Summarised: only with summaries on.
        ready.summaryState = .written
        #expect(!harness.lifecycle.canSummarize(ready))
        harness.summaries.isOn = true
        #expect(harness.lifecycle.canSummarize(ready))
    }

    @Test("turning summaries off ends the summary, which goes back to none when the call had none")
    func turnOffWithoutEarlierSummary() async throws {
        let summarizer = FakeSummarizer(.hang)
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { summarizer.prompts.count == 1 })
        harness.summaries.isOn = false
        harness.lifecycle.turnOffSummary()
        #expect(await harness.eventually { summarizer.cancelledCount == 1 })
        await harness.lifecycle.waitUntilSummaryIdle()

        #expect(call.summaryState == .none)
        #expect(call.summary == nil)
        #expect(harness.lifecycle.runningSummaries.isEmpty)
    }

    @Test("turning summaries off ends the summary and the earlier summary stays")
    func turnOffWithEarlierSummary() async throws {
        let summarizer = FakeSummarizer(.hang)
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        call.summary = CallSummary(text: "Prima", language: "it-IT")
        call.summaryState = .written
        try harness.context.save()

        harness.lifecycle.summarize(call)
        #expect(await harness.eventually { summarizer.prompts.count == 1 })
        harness.summaries.isOn = false
        harness.lifecycle.turnOffSummary()
        #expect(await harness.eventually { summarizer.cancelledCount == 1 })
        await harness.lifecycle.waitUntilSummaryIdle()

        #expect(call.summaryState == .written)
        #expect(call.summary?.text == "Prima")
    }

    @Test("turning summaries off while a summary waits for a retry makes no further attempt")
    func turnOffWhileAwaitingRetry() async throws {
        let summarizer = FakeSummarizer(.fail)
        let harness = try CallHarness(summarizer: summarizer, summariesOn: true)
        defer { harness.cleanUp() }
        let failing = try summarisableCall(harness)
        let withSummary = try summarisableCall(harness)
        withSummary.summary = CallSummary(text: "Prima", language: "it-IT")
        withSummary.summaryState = .written
        try harness.context.save()

        harness.lifecycle.summarize(failing)
        harness.lifecycle.summarize(withSummary)
        #expect(await harness.eventually { failing.summaryState == .awaitingRetry && withSummary.summaryState == .awaitingRetry })

        harness.summaries.isOn = false
        harness.lifecycle.turnOffSummary()
        #expect(failing.summaryState == .none)
        #expect(withSummary.summaryState == .written)
        #expect(withSummary.summary?.text == "Prima")

        let asked = summarizer.prompts.count
        harness.lifecycle.networkAvailable()
        await harness.lifecycle.waitUntilSummaryIdle()
        #expect(summarizer.prompts.count == asked)
    }

    @Test("existing summaries stay when summaries are off")
    func summariesStayWhenOff() throws {
        let harness = try CallHarness(summarizer: FakeSummarizer(.fail), summariesOn: false)
        defer { harness.cleanUp() }
        let call = try summarisableCall(harness)
        call.summary = CallSummary(text: "Prima", language: "it-IT")
        call.summaryState = .written
        try harness.context.save()

        harness.lifecycle.turnOffSummary()

        #expect(call.summaryState == .written)
        #expect(SummaryContent(call: call) != nil)
    }
}
