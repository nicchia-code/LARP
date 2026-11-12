import Foundation

/// What one reading of Microsoft Teams found.
struct TeamsReadout: Sendable, Equatable {
    /// The meeting Teams shows; `nil` when Teams is not running, shows no meeting or cannot be read.
    var meeting: Meeting?
    /// The reading stopped at a limit or Teams did not answer before the element of the meeting was
    /// found: it says nothing, and the meeting stays as it was.
    var leavesMeetingAsItWas = false

    struct Meeting: Sendable, Equatable {
        /// The title of the meeting; `nil` when it cannot be read.
        var title: String?
        /// The people in the list of participants, cleaned (`TeamsText`); empty while Teams does
        /// not show the list.
        var people: [String]
        /// The person Teams marks as speaking; `nil` when nobody is marked or Teams does not expose
        /// the mark.
        var speaker: String?

        init(title: String? = nil, people: [String] = [], speaker: String? = nil) {
            self.title = title
            self.people = people
            self.speaker = speaker
        }
    }

    static let noMeeting = TeamsReadout(meeting: nil)
    static let leavesMeetingAsItWas = TeamsReadout(meeting: nil, leavesMeetingAsItWas: true)
}

/// The reading of Microsoft Teams, which sits behind this protocol so tests can replace it with a
/// fake Teams that shows meetings, people and speakers.
@MainActor
protocol TeamsReading: AnyObject {
    /// Starts reading Teams: `onReadout` is called on the main actor with every reading, the first
    /// one as soon as it is made. The launch and the quit of Teams are followed; a Teams that is not
    /// running reads as no meeting.
    func start(onReadout: @escaping @MainActor (TeamsReadout) -> Void)
    /// Stops reading at once: the reading in progress is abandoned, nothing more is asked to Teams
    /// and no reading arrives any more.
    func stop()
}
