import AVFoundation
import Foundation

/// Plays the audio tracks of a call together, from any time of the call.
@MainActor
protocol TrackPlayer: AnyObject {
    /// Length of the audio, in seconds; `0` when no track can be read.
    var duration: TimeInterval { get }
    /// Time of the call being heard, valid while playing.
    var currentTime: TimeInterval { get }
    /// Starts (or restarts) all tracks at `time`. `onFinished` runs once, when the
    /// audio reaches its end; it does not run if playback is stopped or restarted first.
    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void)
    func stop()
}

/// `TrackPlayer` that plays the files of a call with `AVAudioEngine`, one player
/// node per file, started at the same host time so that the tracks stay aligned.
@MainActor
final class EngineTrackPlayer: TrackPlayer {
    private struct Track {
        let node: AVAudioPlayerNode
        let file: AVAudioFile
    }

    private let engine = AVAudioEngine()
    private let tracks: [Track]
    private var startTime: TimeInterval = 0
    private var generation = 0
    private var pendingSegments = 0
    private var onFinished: (@MainActor () -> Void)?

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
    }

    var currentTime: TimeInterval {
        guard
            let node = tracks.first?.node,
            let renderTime = node.lastRenderTime,
            let playerTime = node.playerTime(forNodeTime: renderTime)
        else { return startTime }
        return startTime + max(Double(playerTime.sampleTime) / playerTime.sampleRate, 0)
    }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        halt()
        generation += 1
        let generation = generation
        self.onFinished = onFinished
        startTime = time

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

        guard !scheduled.isEmpty else {
            finish()
            return
        }
        do {
            try engine.start()
        } catch {
            halt()
            finish()
            return
        }
        // A short delay lets every node be ready, then all start on the same host time.
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.05)
        for node in scheduled {
            node.play(at: AVAudioTime(hostTime: hostTime))
        }
    }

    func stop() {
        generation += 1
        onFinished = nil
        halt()
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
