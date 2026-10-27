import Foundation
import SwiftData
import Testing

@testable import LARP

private func segment(_ speaker: String, _ start: TimeInterval, _ end: TimeInterval) -> SpeakerSegment {
    SpeakerSegment(speaker: speaker, start: start, end: end)
}

private func span(_ start: TimeInterval, _ end: TimeInterval) -> LineSpan {
    LineSpan(start: start, end: end)
}

@Suite("ParticipantAssignment")
struct ParticipantAssignmentTests {
    @Test("a line goes to the voice that overlaps it most")
    func mostOverlapWins() {
        let segments = [segment("A", 0, 4), segment("B", 4, 10)]
        // 1 s with A, 3 s with B
        let numbers = ParticipantAssignment.assign(lines: [span(3, 7)], segments: segments)
        #expect(numbers == [1])
        let both = ParticipantAssignment.assign(lines: [span(0, 2), span(3, 7)], segments: segments)
        #expect(both == [1, 2])
    }

    @Test("the overlaps of all the segments of a voice add up")
    func overlapsAreSummed() {
        let segments = [segment("A", 0, 1), segment("B", 1, 3), segment("A", 3, 5)]
        // A: 1 + 2 = 3 s, B: 2 s
        let numbers = ParticipantAssignment.assign(
            lines: [span(0, 1), span(0, 5)], segments: segments)
        #expect(numbers == [1, 1])
    }

    @Test("a line without overlap goes to the participant of the nearest recognized line")
    func nearestRecognizedLine() {
        let segments = [segment("A", 0, 2), segment("B", 10, 12)]
        let numbers = ParticipantAssignment.assign(
            lines: [span(0, 1), span(3, 4), span(8, 9), span(10, 11), span(20, 21)], segments: segments)
        // 3-4 is 2 s from 0-1 (A) and 6 s from 10-11; 8-9 is 1 s from 10-11 (B); 20-21 is 9 s from 10-11 (B)
        #expect(numbers == [1, 1, 2, 2, 2])
    }

    @Test("a line equally near two recognized lines goes to the earlier one")
    func nearestTieGoesToEarlierLine() {
        let segments = [segment("A", 0, 1), segment("B", 5, 6)]
        let numbers = ParticipantAssignment.assign(
            lines: [span(0, 1), span(2, 4), span(5, 6)], segments: segments)
        // 2-4 is 1 s from both
        #expect(numbers == [1, 1, 2])
    }

    @Test("a participant takes the number of its first line even when that line has no overlap")
    func numberedByFirstLineWithoutOverlap() {
        let segments = [segment("A", 10, 12), segment("B", 20, 22)]
        // 0-1 follows the nearest recognized line, 10-11 (A)
        let numbers = ParticipantAssignment.assign(
            lines: [span(20, 21), span(0, 1), span(10, 11)], segments: segments)
        #expect(numbers == [2, 1, 1])
    }

    @Test("participants are numbered in the order in which they first speak")
    func numberedByFirstLine() {
        let segments = [segment("X", 0, 5), segment("Y", 5, 10), segment("Z", 10, 15)]
        // Lines out of order: X speaks first in the transcript, then Y, then Z.
        let numbers = ParticipantAssignment.assign(
            lines: [span(11, 12), span(1, 2), span(6, 7), span(12, 13)], segments: segments)
        #expect(numbers == [3, 1, 2, 3])
    }

    @Test("a voice that gets no line gets no number")
    func silentVoiceIsSkipped() {
        let segments = [segment("A", 0, 1), segment("B", 1, 2), segment("C", 2, 3)]
        let numbers = ParticipantAssignment.assign(lines: [span(0, 1), span(2, 3)], segments: segments)
        #expect(numbers == [1, 2])
    }

    @Test("a tie goes to the voice that speaks first")
    func tieGoesToEarlierVoice() {
        let segments = [segment("B", 5, 6), segment("A", 0, 1)]
        let numbers = ParticipantAssignment.assign(lines: [span(0, 6)], segments: segments)
        #expect(numbers == [1])
        // The line overlaps 1 s with each voice: A speaks first.
        let first = ParticipantAssignment.assign(lines: [span(0, 6), span(5, 6)], segments: segments)
        #expect(first == [1, 2])
    }

    @Test("without any recognized line every line goes to Participant 1")
    func noRecognizedLine() {
        #expect(ParticipantAssignment.assign(lines: [span(0, 1), span(5, 6)], segments: []) == [1, 1])
        #expect(
            ParticipantAssignment.assign(lines: [span(0, 1), span(5, 6)], segments: [segment("A", 20, 30)])
                == [1, 1])
        #expect(ParticipantAssignment.assign(lines: [], segments: [segment("A", 0, 1)]).isEmpty)
    }
}

private struct FakeDiarizer: SpeakerDiarizing {
    var result: Result<[SpeakerSegment], any Error>
    var onDiarize: @Sendable () async -> Void = {}

    func diarize(audioAt url: URL) async throws -> [SpeakerSegment] {
        await onDiarize()
        return try result.get()
    }
}

private struct DiarizationFailure: Error {}

@Suite("ParticipantSeparator", .serialized)
@MainActor
struct ParticipantSeparatorTests {
    private func makeCall(in context: ModelContext) -> Call {
        let call = Call(transcriptionLanguage: "it-IT", state: .separatingParticipants)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno a tutti"))
        call.lines.append(TranscriptLine(speakerKind: .others, start: 2, end: 4, text: "Ciao, sono Anna"))
        call.lines.append(TranscriptLine(speakerKind: .others, start: 5, end: 7, text: "Io sono Marco"))
        call.lines.append(TranscriptLine(speakerKind: .others, start: 8, end: 9, text: "Ancora Anna"))
        context.insert(call)
        return call
    }

    private func sortedLines(_ call: Call) -> [TranscriptLine] {
        call.lines.sorted { $0.start < $1.start }
    }

    @Test("every Others line is given to a participant and the Me lines do not change")
    func separatesOthersLines() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)
        let diarizer = FakeDiarizer(
            result: .success([segment("A", 2, 4), segment("B", 5, 7), segment("A", 8, 9)]))

        try await ParticipantSeparator(diarizer: diarizer).separate(call)

        let lines = sortedLines(call)
        #expect(lines.map(\.speakerKind) == [.me, .participant, .participant, .participant])
        #expect(lines.map(\.speakerName) == ["Io", "Partecipante 1", "Partecipante 2", "Partecipante 1"])
        #expect(lines[1].participant === lines[3].participant)
        #expect(lines[0].participant == nil)
        #expect(call.participants.map(\.number).sorted() == [1, 2])
    }

    @Test("a failed diarization leaves the transcript with Me and Others")
    func failureLeavesTranscript() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)
        let separator = ParticipantSeparator(diarizer: FakeDiarizer(result: .failure(DiarizationFailure())))

        await #expect(throws: DiarizationFailure.self) {
            try await separator.separate(call)
        }

        #expect(sortedLines(call).map(\.speakerKind) == [.me, .others, .others, .others])
        #expect(call.participants.isEmpty)
    }

    @Test("a call without Others lines is separated without analysing the audio")
    func noOthersLinesSkipsDiarization() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = Call(transcriptionLanguage: "it-IT", state: .separatingParticipants)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Parlo da solo"))
        container.mainContext.insert(call)

        try await ParticipantSeparator(diarizer: FakeDiarizer(result: .failure(DiarizationFailure())))
            .separate(call)

        #expect(call.participants.isEmpty)
        #expect(call.lines.map(\.speakerKind) == [.me])
    }

    @Test("a separation that starts again replaces the participants of the previous one")
    func separationCanRunAgain() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)
        let first = FakeDiarizer(result: .success([segment("A", 2, 4), segment("B", 5, 7), segment("A", 8, 9)]))
        try await ParticipantSeparator(diarizer: first).separate(call)

        let second = FakeDiarizer(result: .success([segment("A", 2, 9)]))
        try await ParticipantSeparator(diarizer: second).separate(call)

        #expect(call.participants.map(\.number) == [1])
        #expect(sortedLines(call).map(\.speakerName) == ["Io", "Partecipante 1", "Partecipante 1", "Partecipante 1"])
    }

    @Test("when no voice is found every Others line goes to Participant 1")
    func noVoicesFound() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)

        try await ParticipantSeparator(diarizer: FakeDiarizer(result: .success([]))).separate(call)

        #expect(sortedLines(call).map(\.speakerKind) == [.me, .participant, .participant, .participant])
        #expect(sortedLines(call).map(\.speakerName) == ["Io", "Partecipante 1", "Partecipante 1", "Partecipante 1"])
        #expect(call.participants.map(\.number) == [1])
    }

    @Test("a line no voice overlaps is given to the participant of the nearest recognized line")
    func unrecognizedLineFollowsNearest() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)
        // Only the line at 5-7 and the one at 8-9 overlap a voice; 2-4 is the nearest to 5-7.
        let diarizer = FakeDiarizer(result: .success([segment("A", 5, 7), segment("B", 8, 9)]))

        try await ParticipantSeparator(diarizer: diarizer).separate(call)

        #expect(sortedLines(call).map(\.speakerName) == ["Io", "Partecipante 1", "Partecipante 1", "Partecipante 2"])
        #expect(call.participants.map(\.number).sorted() == [1, 2])
    }

    @Test("a call deleted during the separation stops it cleanly")
    func deletedCallStopsSeparation() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let call = makeCall(in: context)
        try context.save()

        nonisolated(unsafe) let unsafeCall = call
        nonisolated(unsafe) let unsafeContext = context
        let diarizer = FakeDiarizer(
            result: .success([segment("A", 2, 9)]),
            onDiarize: {
                await MainActor.run {
                    try? ArchiveStore.delete(unsafeCall, in: unsafeContext)
                }
            })

        await #expect(throws: CancellationError.self) {
            try await ParticipantSeparator(diarizer: diarizer).separate(call)
        }
        #expect(try context.fetch(FetchDescriptor<Participant>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Call>()).isEmpty)
    }

    @Test("a cancelled separation changes nothing")
    func cancelledSeparationChangesNothing() async throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let call = makeCall(in: container.mainContext)
        let gate = Task<Void, Never> { try? await Task.sleep(for: .seconds(30)) }
        let diarizer = FakeDiarizer(
            result: .success([segment("A", 2, 9)]), onDiarize: { await gate.value })

        let task = Task { @MainActor in
            try await ParticipantSeparator(diarizer: diarizer).separate(call)
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        gate.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(sortedLines(call).map(\.speakerKind) == [.me, .others, .others, .others])
        #expect(call.participants.isEmpty)
    }
}

@Suite("call machine: speaker separation")
struct SeparationTransitionTests {
    @Test("Separating participants → Ready when the participants are separated and refinement is off")
    func separatedGoesReady() {
        #expect(
            CallStateMachine.target(from: .separatingParticipants, on: .participantsSeparated(refinementOn: false))
                == .state(.ready))
    }

    @Test("Separating participants → Awaiting separation retry when it fails")
    func failureAwaitsRetry() {
        #expect(
            CallStateMachine.target(from: .separatingParticipants, on: .separationFailed)
                == .state(.awaitingSeparationRetry))
    }

    @Test("an app launch during the separation starts it again")
    func launchRestartsSeparation() {
        #expect(
            CallStateMachine.target(from: .separatingParticipants, on: .appLaunched(languageReady: true))
                == .state(.separatingParticipants))
    }

    @Test("Awaiting separation retry → Separating participants on network or launch")
    func retryOnNetworkOrLaunch() {
        #expect(
            CallStateMachine.target(from: .awaitingSeparationRetry, on: .networkAvailable)
                == .state(.separatingParticipants))
        #expect(
            CallStateMachine.target(from: .awaitingSeparationRetry, on: .appLaunched(languageReady: false))
                == .state(.separatingParticipants))
    }

    @Test("rename keeps the state and delete ends the call, in both states")
    func renameAndDelete() {
        for state in [CallState.separatingParticipants, .awaitingSeparationRetry] {
            #expect(CallStateMachine.target(from: state, on: .renameCall) == .state(state))
            #expect(CallStateMachine.target(from: state, on: .deleteCall) == .deleted)
        }
    }
}
