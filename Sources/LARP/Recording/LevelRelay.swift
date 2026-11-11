import Foundation
import Synchronization

/// Hands the levels of the two tracks to the main actor at most 20 times a second, together: the
/// private queues of the tracks call `submit` as often as they measure (every 50 ms each), and the
/// latest level of each track goes to `deliver` once per 50 ms.
final class LevelRelay: Sendable {
    private struct State {
        var latest: [AudioTrack: TrackLevel] = [:]
        var isScheduled = false
    }

    /// The shortest time between two deliveries.
    static let interval: Duration = .milliseconds(50)

    private let state = Mutex(State())
    private let deliver: @MainActor @Sendable ([AudioTrack: TrackLevel]) -> Void

    init(deliver: @escaping @MainActor @Sendable ([AudioTrack: TrackLevel]) -> Void) {
        self.deliver = deliver
    }

    /// Called from the private queue of a track.
    func submit(_ track: AudioTrack, _ level: TrackLevel) {
        let schedules = state.withLock { state -> Bool in
            state.latest[track] = level
            guard !state.isScheduled else { return false }
            state.isScheduled = true
            return true
        }
        guard schedules else { return }
        Task { [self] in
            try? await Task.sleep(for: Self.interval)
            let levels = state.withLock { state -> [AudioTrack: TrackLevel] in
                state.isScheduled = false
                defer { state.latest = [:] }
                return state.latest
            }
            await deliver(levels)
        }
    }
}
