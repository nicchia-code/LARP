import Foundation
import Testing

@testable import LARP

@Suite("Meeting information in the proposal and the live window")
struct TeamsProposalTests {
    private func teams(
        title: String? = nil, people: [String] = [], speaker: String? = nil
    ) -> TeamsReadout.Meeting {
        TeamsReadout.Meeting(title: title, people: people, speaker: speaker)
    }

    // MARK: Proposal card

    @Test("the title of the Teams meeting comes first, then the calendar event, then none")
    func proposalTitle() {
        let event = CalendarMeeting(title: "Pianificazione", invitees: [])
        #expect(ProposalMeeting.resolve(teams: teams(title: "Daily"), event: event).title == "Daily")
        #expect(ProposalMeeting.resolve(teams: teams(), event: event).title == "Pianificazione")
        #expect(ProposalMeeting.resolve(teams: nil, event: event).title == "Pianificazione")
        #expect(ProposalMeeting.resolve(teams: teams(title: "  "), event: event).title == "Pianificazione")
        #expect(ProposalMeeting.resolve(teams: nil, event: nil).title == nil)
        #expect(ProposalMeeting.resolve(teams: teams(), event: CalendarMeeting(title: nil, invitees: [])).title == nil)
    }

    @Test("the number of people comes from Teams, else from the invited people counting the user")
    func proposalPeople() {
        let event = CalendarMeeting(title: "Pianificazione", invitees: ["Anna", "Marco"])
        #expect(ProposalMeeting.resolve(teams: teams(people: ["A", "B", "C", "D"]), event: event).peopleCount == 4)
        #expect(ProposalMeeting.resolve(teams: teams(), event: event).peopleCount == 3)
        #expect(ProposalMeeting.resolve(teams: nil, event: event).peopleCount == 3)
        #expect(ProposalMeeting.resolve(teams: nil, event: CalendarMeeting(title: "x", invitees: [])).peopleCount == nil)
        #expect(ProposalMeeting.resolve(teams: nil, event: nil) == .unknown)
    }

    @Test("the card says \"Call rilevata\" without a title and writes the number of people")
    func proposalTexts() {
        AppLanguage.$override.withValue(.italian) {
            #expect(ProposalMeeting.unknown.displayTitle == "Call rilevata")
            #expect(ProposalMeeting(title: "Daily", peopleCount: 5).displayTitle == "Daily")
            #expect(ProposalMeeting(title: nil, peopleCount: 5).peopleText == "5 persone")
            #expect(ProposalMeeting(title: nil, peopleCount: 1).peopleText == "1 persona")
            #expect(ProposalMeeting.unknown.peopleText == nil)
        }
        AppLanguage.$override.withValue(.english) {
            #expect(ProposalMeeting.unknown.displayTitle == "Call detected")
            #expect(ProposalMeeting(title: nil, peopleCount: 5).peopleText == "5 people")
            #expect(ProposalMeeting(title: nil, peopleCount: 1).peopleText == "1 person")
        }
    }

    // MARK: During a recording

    @Test("during a recording the popover and the live window say the title and the number of people")
    func recordingLine() {
        AppLanguage.$override.withValue(.italian) {
            let meeting = teams(title: "Daily", people: ["Anna", "Marco", "Giulia"])
            #expect(RecordingMeetingLine.text(meeting: meeting, callTitle: nil) == "Daily · 3 persone")
            // The title already shown as the title of the call is not said twice.
            #expect(RecordingMeetingLine.text(meeting: meeting, callTitle: "Daily") == "3 persone")
            #expect(RecordingMeetingLine.text(meeting: teams(title: "Daily"), callTitle: "Altro") == "Daily")
            #expect(RecordingMeetingLine.text(meeting: teams(title: "Daily"), callTitle: "Daily") == nil)
            #expect(RecordingMeetingLine.text(meeting: teams(), callTitle: nil) == nil)
            #expect(RecordingMeetingLine.text(meeting: nil, callTitle: "Daily") == nil)
        }
    }

    // MARK: Live window

    @Test("a line of Altri takes the name Teams marked as speaking when it started")
    func speakerAtLineStart() {
        let spans = [
            SpeakerSpan(start: 2, end: 10, name: "Anna"),
            SpeakerSpan(start: 12, end: 20, name: nil),
            SpeakerSpan(start: 20, end: 30, name: "Marco"),
        ]
        #expect(LiveTeamsNames.speaker(at: 2, spans: spans, current: "Giulia") == "Anna")
        #expect(LiveTeamsNames.speaker(at: 9.9, spans: spans, current: "Giulia") == "Anna")
        // Nobody was marked, or Teams left a gap: the line stays "Altri".
        #expect(LiveTeamsNames.speaker(at: 15, spans: spans, current: "Giulia") == nil)
        #expect(LiveTeamsNames.speaker(at: 11, spans: spans, current: "Giulia") == nil)
        #expect(LiveTeamsNames.speaker(at: 1, spans: spans, current: "Giulia") == nil)
        #expect(LiveTeamsNames.speaker(at: 25, spans: spans, current: "Giulia") == "Marco")
        // After the last closed span, the span still open belongs to the speaker marked now.
        #expect(LiveTeamsNames.speaker(at: 30, spans: spans, current: "Giulia") == "Giulia")
        #expect(LiveTeamsNames.speaker(at: 40, spans: spans, current: nil) == nil)
        #expect(LiveTeamsNames.speaker(at: 3, spans: [], current: "Giulia") == "Giulia")
    }

    @Test("Nella call lists the people Teams shows and marks who Teams indicates as speaking")
    func members() {
        let members = LiveTeamsNames.members(people: ["Anna Rossi", "Marco", "Giulia"], speaker: "marco")
        #expect(members.map(\.name) == ["Anna Rossi", "Marco", "Giulia"])
        #expect(members.map(\.isSpeaking) == [false, true, false])
        #expect(LiveTeamsNames.members(people: ["Anna"], speaker: nil).map(\.isSpeaking) == [false])
        #expect(LiveTeamsNames.members(people: [], speaker: "Anna").isEmpty)
    }
}
