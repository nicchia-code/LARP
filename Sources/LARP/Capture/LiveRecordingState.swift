import Foundation
import Observation

/// What the pill and the live window show of the recording in progress besides what the recorder
/// knows (state, elapsed time): the call being recorded, the levels of the two tracks, the
/// waveform made of them and the text being recognised.
///
/// The text being recognised comes from the volatile results of the live transcription: every
/// result replaces the previous one and nothing of it is stored.
@MainActor
@Observable
final class LiveRecordingState {
    /// How many bars of the waveform are taken from one second of levels: one per 50 ms.
    static let barsPerSecond = 20
    /// The bars of the waveform of the pill.
    static let pillBarCount = 20

    /// The call being recorded; `nil` outside a recording.
    private(set) var call: Call?
    private(set) var microphone = TrackLevel.silent
    private(set) var system = TrackLevel.silent
    /// The last `pillBarCount` bars of 50 ms, from 0 to 1: the loudest of the two tracks.
    private(set) var recentBars: [Double] = Array(repeating: 0, count: pillBarCount)
    /// The loudest level of every second of the recording, from 0 to 1, oldest first.
    private(set) var secondBars: [Double] = []
    /// Who is saying what is being recognised; `nil` when nothing is.
    private(set) var recognising: RecognisedText?
    /// Whether the recording is transcribed live.
    private(set) var isTranscribing = false

    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var beganAt = Date.distantPast
    @ObservationIgnored private var barIndex = 0
    @ObservationIgnored private var barPeak = 0.0
    @ObservationIgnored private var secondPeak = 0.0

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    /// `recorder.RECORDING_STARTED`: the call being recorded is known.
    func begin(call: Call) {
        reset()
        self.call = call
        beganAt = now()
    }

    /// `recorder.RECORDING_STOPPED`.
    func end() {
        reset()
    }

    /// Once the live transcription runs: without it the live window says that there is no live
    /// transcription.
    func transcriptionStarted() {
        guard call != nil else { return }
        isTranscribing = true
    }

    /// The level of a track, from the capture. Ignored when there is no recording. The bars that
    /// the time since the last level completed are closed first, so nothing wakes the main actor
    /// besides the levels themselves.
    func levels(_ track: AudioTrack, _ level: TrackLevel) {
        guard call != nil else { return }
        advance()
        switch track {
        case .microphone: microphone = level
        case .system: system = level
        }
        barPeak = max(barPeak, level.level)
    }

    /// A volatile or final result of the live transcription: it replaces what was recognised.
    /// An empty text, which follows a final result, clears what a track was recognising, and
    /// leaves the text of the other track alone.
    func recognised(_ text: RecognisedText) {
        guard call != nil else { return }
        if text.text.isEmpty {
            if recognising?.speaker == text.speaker { recognising = nil }
        } else {
            recognising = text
        }
    }

    /// Closes the bars of 50 ms, and the seconds they complete, up to the time of now.
    func advance() {
        let target = Int(now().timeIntervalSince(beganAt) * Double(Self.barsPerSecond))
        while barIndex < target {
            recentBars.append(barPeak)
            recentBars.removeFirst(recentBars.count - Self.pillBarCount)
            secondPeak = max(secondPeak, barPeak)
            barPeak = 0
            barIndex += 1
            if barIndex % Self.barsPerSecond == 0 {
                secondBars.append(secondPeak)
                secondPeak = 0
            }
        }
    }

    private func reset() {
        call = nil
        microphone = .silent
        system = .silent
        recentBars = Array(repeating: 0, count: Self.pillBarCount)
        secondBars = []
        recognising = nil
        isTranscribing = false
        barIndex = 0
        barPeak = 0
        secondPeak = 0
    }
}
