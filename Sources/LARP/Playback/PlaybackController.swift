import Foundation
import Observation

/// Playback of the audio of the call shown in the archive window (machine `playback`).
///
/// - `Stopped` (initial): nothing plays; `play()` starts from the beginning.
/// - `Playing`: the audio plays and `currentLineIndex` follows it.
/// - `Paused`: the audio is held where it was.
///
/// Showing another call (`show(_:)`), closing the window (`stop()`) and deleting
/// the call (`show(nil)`) all lead back to `Stopped`.
@MainActor
@Observable
final class PlaybackController {
    enum State: Equatable, Sendable {
        case stopped
        case playing
        case paused
    }

    /// Creates the player for the audio files of a call.
    typealias PlayerFactory = @MainActor ([URL]) -> any TrackPlayer

    private(set) var state: State = .stopped
    /// Current time in the call, in seconds.
    private(set) var currentTime: TimeInterval = 0
    /// Total time, in seconds.
    private(set) var duration: TimeInterval = 0
    /// Index (in transcript order) of the line being heard, while playing or paused.
    private(set) var currentLineIndex: Int?
    /// Whether the shown call has audio that can be played.
    private(set) var canPlay = false
    /// The call whose audio is loaded.
    private(set) var callID: UUID?

    @ObservationIgnored private var timeline = TranscriptTimeline.empty
    @ObservationIgnored private var player: (any TrackPlayer)?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let makePlayer: PlayerFactory
    @ObservationIgnored private let tickInterval: Duration

    init(
        tickInterval: Duration = .milliseconds(100),
        makePlayer: @escaping PlayerFactory = { EngineTrackPlayer(urls: $0) }
    ) {
        self.tickInterval = tickInterval
        self.makePlayer = makePlayer
    }

    // MARK: Showing a call

    /// Shows a call (`nil` for none). Any other call than the loaded one stops playback.
    /// Showing the loaded call again only loads its audio once it is no longer being recorded.
    func show(_ call: Call?) {
        guard let call else {
            unload()
            return
        }
        if call.id != callID {
            unload()
            callID = call.id
        }
        guard player == nil, call.state != .recording else {
            if player == nil { duration = call.duration }
            return
        }
        let player = makePlayer([call.micAudioURL, call.systemAudioURL])
        self.player = player
        canPlay = player.duration > 0
        duration = canPlay ? player.duration : call.duration
    }

    /// Updates the time spans of the transcript lines, sorted by start.
    func setTimeline(_ spans: [LineTiming]) {
        timeline = TranscriptTimeline(spans: spans)
        currentLineIndex = state == .stopped ? nil : timeline.lineIndex(at: currentTime)
    }

    // MARK: Events

    /// `user.PLAY`: Stopped → Playing from the beginning; Paused → Playing from where it was.
    func play() {
        switch state {
        case .stopped: start(at: 0)
        case .paused: start(at: currentTime)
        case .playing: break
        }
    }

    /// `user.PAUSE`: Playing → Paused.
    func pause() {
        guard state == .playing, let player else { return }
        currentTime = min(player.currentTime, duration)
        player.stop()
        stopTicking()
        state = .paused
        currentLineIndex = timeline.lineIndex(at: currentTime)
    }

    func togglePlayPause() {
        if state == .playing { pause() } else { play() }
    }

    /// `user.SELECT_SENTENCE`: from any state, Playing from the start of the sentence.
    func play(fromSentenceStart time: TimeInterval) {
        guard canPlay else { return }
        start(at: time)
    }

    /// Moves the playhead with the progress bar: Playing keeps playing from `time`,
    /// Paused stays paused at `time`. Ignored while Stopped.
    func seek(to time: TimeInterval) {
        let time = min(max(time, 0), duration)
        switch state {
        case .stopped:
            break
        case .playing:
            start(at: time)
        case .paused:
            currentTime = time
            currentLineIndex = timeline.lineIndex(at: time)
        }
    }

    /// `user.CLOSE_WINDOW`, and the way out of every state: → Stopped.
    func stop() {
        player?.stop()
        stopTicking()
        state = .stopped
        currentTime = 0
        currentLineIndex = nil
    }

    // MARK: Private

    private func start(at time: TimeInterval) {
        guard let player, canPlay else { return }
        let time = min(max(time, 0), duration)
        currentTime = time
        currentLineIndex = timeline.lineIndex(at: time)
        // The state is set first: a player with nothing left to play calls back at once.
        state = .playing
        startTicking()
        player.start(at: time) { [weak self] in
            self?.playbackEnded()
        }
    }

    /// `playback.PLAYBACK_ENDED`: Playing → Stopped.
    private func playbackEnded() {
        guard state == .playing else { return }
        stop()
    }

    private func unload() {
        stop()
        player = nil
        callID = nil
        canPlay = false
        duration = 0
        timeline = .empty
    }

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self, tickInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        guard state == .playing, let player else { return }
        let time = min(player.currentTime, duration)
        currentTime = time
        let index = timeline.lineIndex(at: time)
        if index != currentLineIndex { currentLineIndex = index }
    }
}
