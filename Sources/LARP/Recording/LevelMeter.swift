import Foundation

/// What a track is doing at one moment: the level of its last 50 ms and whether someone
/// is speaking on it.
struct TrackLevel: Equatable, Sendable {
    /// Peak of the last 50 ms on a scale from 0 (−60 dBFS or less) to 1 (0 dBFS).
    var level: Double
    var isSpeaking: Bool

    static let silent = TrackLevel(level: 0, isSpeaking: false)
}

/// Measures the level of one track from its audio at `AudioFormats.storageSampleRate`:
/// one peak every 50 ms, so 20 values a second, on a scale from −60 to 0 dBFS.
///
/// A track speaks once it stays above −40 dBFS for at least 200 ms and stops 500 ms after
/// it fell below. Not thread safe: it lives on the private queue of its track.
struct LevelMeter {
    static let windowSeconds = 0.05
    static let floorDecibels: Float = -60
    static let speakingDecibels: Float = -40
    /// Consecutive windows above the threshold before the track speaks (200 ms).
    static let windowsToStartSpeaking = 4
    /// Consecutive windows below the threshold before the track stops speaking (500 ms).
    static let windowsToStopSpeaking = 10

    private let windowFrames: Int
    private var framesInWindow = 0
    private var peak: Float = 0
    private var windowsAbove = 0
    private var windowsBelow = 0
    private var isSpeaking = false

    init(sampleRate: Double = AudioFormats.storageSampleRate) {
        windowFrames = max(1, Int(sampleRate * Self.windowSeconds))
    }

    /// Takes the next samples of the track and calls `emit` for every 50 ms window they complete.
    mutating func consume(_ samples: UnsafeBufferPointer<Float>, emit: (TrackLevel) -> Void) {
        for sample in samples {
            peak = max(peak, abs(sample))
            framesInWindow += 1
            if framesInWindow == windowFrames {
                emit(closeWindow())
            }
        }
    }

    private mutating func closeWindow() -> TrackLevel {
        let decibels = peak > 0 ? 20 * log10(peak) : -.infinity
        let level = Double(min(max((decibels - Self.floorDecibels) / -Self.floorDecibels, 0), 1))
        if decibels > Self.speakingDecibels {
            windowsAbove += 1
            windowsBelow = 0
        } else {
            windowsBelow += 1
            windowsAbove = 0
        }
        if !isSpeaking, windowsAbove >= Self.windowsToStartSpeaking {
            isSpeaking = true
        } else if isSpeaking, windowsBelow >= Self.windowsToStopSpeaking {
            isSpeaking = false
        }
        framesInWindow = 0
        peak = 0
        return TrackLevel(level: level, isSpeaking: isSpeaking)
    }
}
