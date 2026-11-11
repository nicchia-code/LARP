import Foundation

/// What one reading of Microsoft Teams found.
struct TeamsReadout: Sendable, Equatable {
    /// The meeting Teams shows; `nil` when Teams is not running, shows no meeting or cannot be read.
    var meeting: Meeting?

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
}

/// The reading of Microsoft Teams, which sits behind this protocol so tests can replace it with a
/// fake Teams that shows meetings, people and speakers.
@MainActor
protocol TeamsReading: AnyObject {
    /// Starts reading Teams: `onReadout` is called on the main actor with every reading, the first
    /// one as soon as it is made. The launch and the quit of Teams are followed.
    func start(onReadout: @escaping @MainActor (TeamsReadout) -> Void)
    /// Stops reading at once; no reading arrives any more.
    func stop()
}
