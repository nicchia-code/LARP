import AVFoundation
import Foundation

/// Plays the audio tracks of a call together, from any time of the call.
@MainActor
protocol TrackPlayer: AnyObject {
    /// Length of the audio, in seconds; `0` when no track can be read.
    var duration: TimeInterval { get }
    /// Time of the call being heard, valid while playing.
    var currentTime: TimeInterval { get }
    /// Runs, with the time reached, when playback cannot go on because the audio output
    /// changed and the engine could not start again. The player is then halted: it plays
    /// nothing, and `start(at:onFinished:)` restarts it on the output current at that moment.
    var onInterrupted: (@MainActor (TimeInterval) -> Void)? { get set }
    /// Starts (or restarts) all tracks at `time`. `onFinished` runs once, when the
    /// audio reaches its end; it does not run if playback is stopped or restarted first.
    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void)
    func stop()
    /// Stops playback and releases what the player observes; the player is not used afterwards.
    func unload()
}

/// `TrackPlayer` that plays the files of a call with `AVAudioEngine`, one player
/// node per file, started at the same host time so that the tracks stay aligned.
@MainActor
final class EngineTrackPlayer: TrackPlayer {
    private struct Track {
        let node: AVAudioPlayerNode
        let file: AVAudioFile
    }

    private enum Launch {
        case started
        case reachedEnd
        case engineFailed
    }

    let engine = AVAudioEngine()
    private let tracks: [Track]
    private var startTime: TimeInterval = 0
    /// Last time of the call known to be reached: it survives the engine being stopped, when
    /// the player nodes no longer report a render time.
    private var reachedTime: TimeInterval = 0
    private var generation = 0
    private var pendingSegments = 0
    private var onFinished: (@MainActor () -> Void)?
    private var configurationObserver: (any NSObjectProtocol)?

    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    let duration: TimeInterval

    /// Files that are missing, empty or unreadable are skipped.
    init(urls: [URL]) {
        var tracks: [Track] = []
        for url in urls {
            guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { continue }
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            tracks.append(Track(node: node, file: file))
        }
        self.tracks = tracks
        self.duration = tracks.map { Double($0.file.length) / $0.file.processingFormat.sampleRate }.max() ?? 0
        // `macos.AUDIO_DEVICES_CHANGED`: the engine stops when the audio output changes.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.outputChanged() }
        }
    }

    var currentTime: TimeInterval {
        guard
            let node = tracks.first?.node,
            let renderTime = node.lastRenderTime,
            let playerTime = node.playerTime(forNodeTime: renderTime)
        else { return reachedTime }
        reachedTime = startTime + max(Double(playerTime.sampleTime) / playerTime.sampleRate, 0)
        return reachedTime
    }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        self.onFinished = onFinished
        if launch(at: time) != .started { finish() }
    }

    func stop() {
        generation += 1
        onFinished = nil
        halt()
    }

    func unload() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        onInterrupted = nil
        stop()
    }

    /// Schedules every track from `time` and starts them together on the engine, which
    /// starts with the format of the output current at this moment.
    private func launch(at time: TimeInterval) -> Launch {
        halt()
        generation += 1
        let generation = generation
        startTime = time
        reachedTime = time

        var scheduled: [AVAudioPlayerNode] = []
        for track in tracks {
            let sampleRate = track.file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
            guard startFrame < track.file.length else { continue }
            let frameCount = AVAudioFrameCount(track.file.length - startFrame)
            track.node.scheduleSegment(
                track.file,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil,
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                Task { @MainActor in self?.segmentFinished(generation: generation) }
            }
            scheduled.append(track.node)
        }
        pendingSegments = scheduled.count

        guard !scheduled.isEmpty else { return .reachedEnd }
        do {
            try engine.start()
        } catch {
            halt()
            return .engineFailed
        }
        // A short delay lets every node be ready, then all start on the same host time.
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.05)
        for node in scheduled {
            node.play(at: AVAudioTime(hostTime: hostTime))
        }
        return .started
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: the engine is stopped, every node is connected again to
    /// the main mixer with the format of its file and, while playing, the audio goes on from
    /// the time reached before the change; if the engine cannot start again, the player halts
    /// and reports the time reached through `onInterrupted`.
    private func outputChanged() {
        let wasPlaying = onFinished != nil
        // Read before anything stops: `start(at:)` and `halt()` reset what the nodes report.
        let position = min(currentTime, duration)
        generation += 1
        halt()
        for track in tracks {
            engine.connect(track.node, to: engine.mainMixerNode, format: track.file.processingFormat)
        }
        guard wasPlaying else { return }
        switch launch(at: position) {
        case .started:
            break
        case .reachedEnd:
            finish()
        case .engineFailed:
            onFinished = nil
            generation += 1
            onInterrupted?(position)
        }
    }

    private func halt() {
        for track in tracks { track.node.stop() }
        if engine.isRunning { engine.stop() }
    }

    private func segmentFinished(generation: Int) {
        guard generation == self.generation else { return }
        pendingSegments -= 1
        if pendingSegments <= 0 { finish() }
    }

    private func finish() {
        let callback = onFinished
        onFinished = nil
        generation += 1
        halt()
        callback?()
    }
}
