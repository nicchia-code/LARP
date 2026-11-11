import Foundation
import SwiftData
import Testing

@testable import LARP

private func span(_ start: TimeInterval, _ end: TimeInterval) -> LineSpan {
    LineSpan(start: start, end: end)
}

private func speaking(_ start: TimeInterval, _ end: TimeInterval, _ name: String?) -> SpeakerSpan {
    SpeakerSpan(start: start, end: end, name: name)
}

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

// MARK: - Names from Teams: the rule

@Suite("Names from Teams after the separation")
struct TeamsSpeakerNamingTests {
    @Test("the name that covers at least 70% of the time of the lines of a participant wins")
    func seventyPercent() {
        let participant = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        // 7 of 10 seconds: exactly 70%.
        #expect(
            TeamsSpeakerNaming.names(
                for: [participant], timeline: [speaking(0, 7, "Anna"), speaking(7, 10, "Marco")]) == [1: "Anna"])
        // 6.9 of 10 seconds: not enough.
        #expect(
            TeamsSpeakerNaming.names(
                for: [participant], timeline: [speaking(0, 6.9, "Anna"), speaking(6.9, 10, "Marco")]).isEmpty)
    }

    @Test("the time of every line is split among the names of the spans that overlap it, over all the lines")
    func splitAmongNames() {
        let participant = ParticipantSpeech(number: 1, lines: [span(0, 4), span(10, 16)])
        // Anna covers 3 s of the first line and 5 s of the second: 8 of 10 seconds.
        let timeline = [
            speaking(1, 4, "Anna"), speaking(4, 9, "Marco"), speaking(11, 16, "Anna"), speaking(10, 11, "Marco"),
        ]
        #expect(TeamsSpeakerNaming.names(for: [participant], timeline: timeline) == [1: "Anna"])
    }

    @Test("the time without a name counts in the total but gives nothing to anyone")
    func silenceCountsInTheTotal() {
        let participant = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        #expect(TeamsSpeakerNaming.names(for: [participant], timeline: [speaking(0, 6, "Anna"), speaking(6, 10, nil)]).isEmpty)
        #expect(TeamsSpeakerNaming.names(for: [participant], timeline: [speaking(0, 8, "Anna"), speaking(8, 10, nil)]) == [1: "Anna"])
    }

    @Test("a name goes to one participant only: the higher share takes it and the other keeps its number")
    func oneNameOneParticipant() {
        let first = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        let second = ParticipantSpeech(number: 2, lines: [span(20, 30)])
        // Anna covers 80% of the first participant and 100% of the second.
        let timeline = [speaking(0, 8, "Anna"), speaking(8, 10, "Marco"), speaking(20, 30, "Anna")]
        #expect(TeamsSpeakerNaming.names(for: [first, second], timeline: timeline) == [2: "Anna"])
    }

    @Test("equal shares of the same name go to the participant with the lower number")
    func equalSharesLowerNumber() {
        let first = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        let second = ParticipantSpeech(number: 2, lines: [span(20, 30)])
        let timeline = [speaking(0, 10, "Anna"), speaking(20, 30, "Anna")]
        #expect(TeamsSpeakerNaming.names(for: [second, first], timeline: timeline) == [1: "Anna"])
    }

    @Test("names written with another case or accents are the same name")
    func foldedNames() {
        let first = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        let second = ParticipantSpeech(number: 2, lines: [span(20, 30)])
        let timeline = [speaking(0, 9, "José"), speaking(20, 30, "jose")]
        #expect(TeamsSpeakerNaming.names(for: [first, second], timeline: timeline) == [2: "jose"])
    }

    @Test("two participants with their own names both get them")
    func twoNames() {
        let first = ParticipantSpeech(number: 1, lines: [span(0, 10)])
        let second = ParticipantSpeech(number: 2, lines: [span(20, 30)])
        let timeline = [speaking(0, 10, "Anna"), speaking(20, 30, "Marco")]
        #expect(TeamsSpeakerNaming.names(for: [first, second], timeline: timeline) == [1: "Anna", 2: "Marco"])
    }

    @Test("without a timeline, or without time in the lines, nobody is named")
    func nothingToGo() {
        #expect(TeamsSpeakerNaming.names(for: [ParticipantSpeech(number: 1, lines: [span(0, 10)])], timeline: []).isEmpty)
        #expect(TeamsSpeakerNaming.names(for: [ParticipantSpeech(number: 1, lines: [span(5, 5)])], timeline: [speaking(0, 10, "Anna")]).isEmpty)
        #expect(TeamsSpeakerNaming.names(for: [ParticipantSpeech(number: 1, lines: [])], timeline: [speaking(0, 10, "Anna")]).isEmpty)
    }
}

// MARK: - The switch

@Suite("Speaker identification switch")
@MainActor
struct SpeakerIdentificationControllerTests {
    @Test("it is on by default and the choice is saved between launches")
    func defaultAndSaved() {
        let defaults = makeDefaults()
        let controller = SpeakerIdentificationController(defaults: defaults)
        #expect(controller.state == .on && controller.isOn)

        controller.turnOff()
        #expect(controller.state == .off)
        #expect(defaults.object(forKey: SettingsKey.speakerIdentification) as? Bool == false)
        #expect(SpeakerIdentificationController(defaults: defaults).state == .off)

        controller.turnOn()
        #expect(controller.state == .on)
        #expect(SpeakerIdentificationController(defaults: defaults).state == .on)
    }
}

// MARK: - The call

/// A separation that gives each line of the others to the participant whose number the test chose
/// by the start time of the line, as the diarization would.
private struct NumberingSeparator: ParticipantSeparating {
    /// The participant number of the lines starting at each time.
    let numbers: [TimeInterval: Int]

    @MainActor
    func separate(_ call: Call) async throws {
        for participant in Array(call.participants) {
            call.modelContext?.delete(participant)
        }
        call.participants.removeAll()
        var participants: [Int: Participant] = [:]
        for line in call.lines where line.speakerKind != .me {
            let number = numbers[line.start] ?? 1
            let participant = participants[number] ?? Participant(number: number)
            if participants[number] == nil {
                call.participants.append(participant)
                participants[number] = participant
            }
            line.speakerKind = .participant
            line.participant = participant
        }
    }
}

@Suite("Meeting titles and names of a call", .serialized)
@MainActor
struct MeetingNamesTests {
    // MARK: Titles

    @Test("the title shown is the one the user gave, else the meeting title, else the default one")
    func displayedTitle() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let language = AppLanguage.italian
        let calendar = Calendar(identifier: .gregorian)
        let defaultTitle = call.displayTitle(calendar: calendar, language: language)
        #expect(defaultTitle.hasPrefix("Registrazione del "))

        call.meetingTitle = "Daily"
        #expect(call.displayTitle(calendar: calendar, language: language) == "Daily")
        call.title = "Il mio titolo"
        #expect(call.displayTitle(calendar: calendar, language: language) == "Il mio titolo")
    }

    @Test("a title typed empty restores the meeting title, else the default one")
    func emptyTitleRestores() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, title: "Mio")
        call.meetingTitle = "Daily"
        let calendar = Calendar(identifier: .gregorian)

        harness.lifecycle.renameCall(call, to: "   ")
        #expect(call.title == nil)
        #expect(call.displayTitle(calendar: calendar, language: .italian) == "Daily")

        call.meetingTitle = nil
        #expect(call.displayTitle(calendar: calendar, language: .italian).hasPrefix("Registrazione del "))
    }

    // MARK: At the start of a recording

    @Test("a recording takes the title and the invited people of the calendar event in progress")
    func calendarEvent() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.calendarMeeting = { CalendarMeeting(title: "Pianificazione", invitees: ["Anna", "Marco"]) }
        await harness.lifecycle.handle(.started(callAppName: "Zoom"))
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == "Pianificazione")
        #expect(call.participantNames == ["Anna", "Marco"])
    }

    @Test("the title of the meeting Teams shows wins over the calendar event, and the names of both are kept")
    func teamsBeforeTheCalendar() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.teamsMeeting = { .init(title: "Daily", people: ["Anna", "Giulia"], speaker: nil) }
        harness.lifecycle.calendarMeeting = { CalendarMeeting(title: "Pianificazione", invitees: ["anna", "Marco"]) }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == "Daily")
        // Teams first, then the invited people not already there.
        #expect(call.participantNames == ["Anna", "Giulia", "Marco"])
    }

    @Test("the calendar event gives its title when Teams shows no meeting title")
    func calendarTitleWhenTeamsHasNone() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.teamsMeeting = { .init(title: nil, people: ["Anna"], speaker: nil) }
        harness.lifecycle.calendarMeeting = { CalendarMeeting(title: "Pianificazione", invitees: []) }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == "Pianificazione")
        #expect(call.participantNames == ["Anna"])
    }

    @Test("without an event in progress, or an event without a title, the call has no meeting title")
    func noEvent() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.calendarMeeting = { CalendarMeeting(title: nil, invitees: ["Anna"]) }
        await harness.lifecycle.handle(.started(callAppName: "Zoom"))
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == nil)
        #expect(call.participantNames == ["Anna"])
    }

    // MARK: After the separation

    /// A call about to be separated: lines of "Io" and of the others, and the timeline of Teams.
    private func separatingCall(
        _ harness: CallHarness, timeline: [SpeakerSpan], participantNames: [String] = []
    ) throws -> Call {
        let call = try harness.insertCall(.separatingParticipants)
        let lines = [
            TranscriptLine(speakerKind: .me, start: 0, end: 4, text: "Ciao"),
            TranscriptLine(speakerKind: .others, start: 5, end: 15, text: "Buongiorno a tutti"),
            TranscriptLine(speakerKind: .others, start: 20, end: 30, text: "Anche da me"),
        ]
        for line in lines {
            call.lines.append(line)
        }
        call.speakerTimeline = timeline
        call.participantNames = participantNames
        try harness.context.save()
        return call
    }

    private func separate(_ harness: CallHarness, _ call: Call) async {
        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilSeparationIdle()
        _ = await harness.eventually { call.state == .ready }
    }

    private var twoVoices: NumberingSeparator { NumberingSeparator(numbers: [5: 1, 20: 2]) }

    @Test("the participants are named after the Teams speakers, as if typed by the user")
    func namesGiven() async throws {
        let harness = try CallHarness(separator: twoVoices)
        defer { harness.cleanUp() }
        let call = try separatingCall(
            harness, timeline: [speaking(5, 15, "Anna"), speaking(20, 30, "Marco")])
        await separate(harness, call)

        let participants = call.participants.sorted { $0.number < $1.number }
        #expect(participants.map(\.name) == ["Anna", "Marco"])
        #expect(participants.map { $0.displayName(language: .italian) } == ["Anna", "Marco"])
        #expect(call.state == .ready)
    }

    @Test("a participant whose best name covers less than 70% keeps its number")
    func lowShare() async throws {
        let harness = try CallHarness(separator: twoVoices)
        defer { harness.cleanUp() }
        let call = try separatingCall(
            harness, timeline: [speaking(5, 11, "Anna"), speaking(11, 15, "Marco"), speaking(20, 30, "Marco")])
        await separate(harness, call)

        let participants = call.participants.sorted { $0.number < $1.number }
        #expect(participants.map(\.name) == [nil, "Marco"])
        #expect(participants[0].displayName(language: .italian) == "Partecipante 1")
    }

    @Test("with the switch off no name is given")
    func switchOff() async throws {
        let harness = try CallHarness(separator: twoVoices, speakerIdentificationOn: false)
        defer { harness.cleanUp() }
        let call = try separatingCall(
            harness, timeline: [speaking(5, 15, "Anna"), speaking(20, 30, "Marco")])
        await separate(harness, call)

        #expect(call.participants.allSatisfy { $0.name == nil })
    }

    @Test("when Teams showed nobody speaking no name is given")
    func noTimeline() async throws {
        let harness = try CallHarness(separator: twoVoices)
        defer { harness.cleanUp() }
        let call = try separatingCall(harness, timeline: [], participantNames: ["Anna", "Marco"])
        await separate(harness, call)

        #expect(call.participants.count == 2)
        #expect(call.participants.allSatisfy { $0.name == nil })
    }

    @Test("a separation that runs again replaces the participants and gives the names again")
    func separatedAgain() async throws {
        let harness = try CallHarness(separator: twoVoices)
        defer { harness.cleanUp() }
        let call = try separatingCall(
            harness, timeline: [speaking(5, 15, "Anna"), speaking(20, 30, "Marco")])
        await separate(harness, call)
        #expect(call.participants.count == 2)

        // The user renames the first participant, then separates again.
        let first = try #require(call.participants.first { $0.number == 1 })
        harness.lifecycle.renameParticipant(first, to: "Anna Rossi")
        #expect(first.name == "Anna Rossi")
        call.state = .separatingParticipants
        try harness.context.save()
        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilSeparationIdle()
        _ = await harness.eventually { call.state == .ready }

        let participants = call.participants.sorted { $0.number < $1.number }
        #expect(participants.map(\.name) == ["Anna", "Marco"])
    }

    // MARK: The names offered when renaming

    @Test("the rename field offers the names kept with the call that no other participant has")
    func offeredNames() async throws {
        let harness = try CallHarness(separator: twoVoices)
        defer { harness.cleanUp() }
        let call = try separatingCall(
            harness, timeline: [speaking(5, 15, "Anna")], participantNames: ["Anna", "Marco", "Giulia"])
        await separate(harness, call)
        let first = try #require(call.participants.first { $0.number == 1 })
        let second = try #require(call.participants.first { $0.number == 2 })
        #expect(first.name == "Anna")

        // The second participant: Anna is taken by the first one.
        #expect(harness.lifecycle.offeredNames(for: second, in: call) == ["Marco", "Giulia"])
        // The first participant may keep its own name among the offered ones.
        #expect(harness.lifecycle.offeredNames(for: first, in: call) == ["Anna", "Marco", "Giulia"])
        // Typed in another case, a name is still the same one.
        harness.lifecycle.renameParticipant(second, to: " marco ")
        #expect(harness.lifecycle.offeredNames(for: first, in: call) == ["Anna", "Giulia"])
    }

    @Test("with the switch off nothing is offered")
    func nothingOfferedWhenOff() async throws {
        let harness = try CallHarness(separator: twoVoices, speakerIdentificationOn: false)
        defer { harness.cleanUp() }
        let call = try separatingCall(harness, timeline: [], participantNames: ["Anna"])
        await separate(harness, call)
        let first = try #require(call.participants.first)
        #expect(harness.lifecycle.offeredNames(for: first, in: call).isEmpty)
    }
}
