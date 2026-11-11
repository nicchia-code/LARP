import Foundation
import Observation

/// Playback of the audio of the call shown in the archive window (machine `playback`).
///
/// - `Stopped` (initial): nothing plays; `play()` starts from the beginning.
/// - `Playing`: the audio plays and `currentLineIndex` follows it.
/// - `Paused`: the audio is held where it was.
///
/// A change of the audio output of the Mac (`macos.AUDIO_DEVICES_CHANGED`) is handled by the
/// player: Playing goes on from the time reached, or becomes Paused if the audio cannot play.
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

    /// The playback of the main window, which the global shortcut to add a bookmark also reads.
    static let shared = PlaybackController()

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
    /// The days of the audio retention in force when it deleted the audio of the shown call; `nil`
    /// while the call has its audio.
    private(set) var audioRemovedAfterDays: Int?
    /// The call whose audio is loaded.
    private(set) var callID: UUID?

    @ObservationIgnored private var timeline = TranscriptTimeline.empty
    @ObservationIgnored private var player: (any TrackPlayer)?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let makePlayer: PlayerFactory
    @ObservationIgnored private let tickInterval: Duration
    /// The speed and the silence skipping, the same for every call.
    let options: PlaybackOptions

    init(
        options: PlaybackOptions = .shared,
        tickInterval: Duration = .milliseconds(100),
        makePlayer: @escaping PlayerFactory = { EngineTrackPlayer(urls: $0) }
    ) {
        self.options = options
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
        audioRemovedAfterDays = call.audioRemovedAfterDays
        if audioRemovedAfterDays != nil {
            // The retention deleted the audio: what was loaded stops, and nothing is loaded again.
            stop()
            player?.unload()
            player = nil
            canPlay = false
            duration = call.duration
            return
        }
        guard player == nil, call.state != .recording else {
            if player == nil { duration = call.duration }
            return
        }
        let player = makePlayer([call.micAudioURL, call.systemAudioURL])
        player.speed = options.speed
        player.onInterrupted = { [weak self] time in self?.playbackInterrupted(at: time) }
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
    /// Does nothing when the call has no audio to play (`canPlay` is false: no readable track,
    /// or the call is still being recorded).
    func play(fromSentenceStart time: TimeInterval) {
        guard canPlay else { return }
        start(at: time)
    }

    /// `user.SELECT_BOOKMARK`: from any state, Playing from the time of the bookmark. When the call
    /// of the bookmark is not the one loaded, its audio is loaded first. Does nothing when the call
    /// has no audio to play.
    func selectBookmark(at time: TimeInterval, of call: Call) {
        show(call)
        play(fromSentenceStart: time)
    }

    /// `user.SELECT_DECISION`: from any state, Playing from the start of the line where the decision was
    /// taken, in the call whose audio is loaded. Does nothing when the call has no audio to play.
    func selectDecision(lineStart time: TimeInterval) {
        play(fromSentenceStart: time)
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

    /// `user.CHANGE_SPEED`: the next speed is saved and applies at once, also to audio playing.
    func changeSpeed() {
        options.changeSpeed()
        player?.speed = options.speed
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

    /// `macos.AUDIO_DEVICES_CHANGED` while Playing, when the audio cannot play on the current
    /// output: Playing → Paused at the time reached, without any notice. The player is already
    /// halted; the next play starts it again on the output current at that moment.
    private func playbackInterrupted(at time: TimeInterval) {
        guard state == .playing else { return }
        currentTime = min(max(time, 0), duration)
        stopTicking()
        state = .paused
        currentLineIndex = timeline.lineIndex(at: currentTime)
    }

    private func unload() {
        stop()
        player?.unload()
        player = nil
        callID = nil
        canPlay = false
        audioRemovedAfterDays = nil
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
        guard options.skipSilence else { return }
        // Skipping a silence is a seek, or the end of the audio when no line is left.
        switch timeline.silenceSkip(at: time, duration: duration) {
        case .seek(let target): seek(to: target)
        case .end: playbackEnded()
        case nil: break
        }
    }
}
