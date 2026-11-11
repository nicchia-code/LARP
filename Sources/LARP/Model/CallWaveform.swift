import Foundation

/// Who a bar of the waveform of a call belongs to.
enum WaveformSpeaker: Hashable, Codable, Sendable {
    /// "Io": a line of the microphone covers the middle of the bar.
    case me
    /// A participant, by number.
    case participant(Int)
    /// "Altri" as a whole: a line of the others without participant.
    case others
    /// No line covers the middle of the bar.
    case silence
}

/// One bar of the waveform of a call: how loud the call is over its share of the time, and who speaks.
struct WaveformBar: Hashable, Codable, Sendable {
    /// 0 to 1.
    var level: Double
    var speaker: WaveformSpeaker
}

/// A transcript line as the waveform needs it, so that the calculation is independent of the store.
struct WaveformLine: Equatable, Sendable {
    let start: TimeInterval
    let end: TimeInterval
    let speaker: WaveformSpeaker
}

/// The waveform of a call: `barCount` bars, each the peak of both tracks over its share of the call
/// on a scale from `floorDecibels` to 0 dBFS, with the speaker of the line covering the middle of its
/// time.
enum Waveform {
    static let barCount = 44
    /// The level of a peak at or below this is 0.
    static let floorDecibels: Double = -50

    /// 0 for silence (and for anything at or below -50 dBFS) up to 1 for 0 dBFS.
    static func level(peak: Float) -> Double {
        guard peak > 0 else { return 0 }
        let decibels = 20 * log10(Double(peak))
        return min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }

    /// The speaker of the first line that covers `time`, `.silence` when none does.
    static func speaker(at time: TimeInterval, in lines: [WaveformLine]) -> WaveformSpeaker {
        lines.first { $0.start <= time && time < $0.end }?.speaker ?? .silence
    }

    /// The bars of a call over `duration` seconds, from the linear peak of each bar (`peaks` has one
    /// per bar) and the lines of the call.
    static func bars(peaks: [Float], duration: TimeInterval, lines: [WaveformLine]) -> [WaveformBar] {
        let ordered = lines.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        return peaks.enumerated().map { index, peak in
            let middle = (Double(index) + 0.5) / Double(peaks.count) * duration
            return WaveformBar(level: level(peak: peak), speaker: speaker(at: middle, in: ordered))
        }
    }
}

extension TranscriptLine {
    /// The line as the waveform sees it: a participant line without participant counts as "Altri".
    var waveformLine: WaveformLine {
        let speaker: WaveformSpeaker =
            switch speakerKind {
            case .me: .me
            case .others: .others
            case .participant: participant.map { .participant($0.number) } ?? .others
            }
        return WaveformLine(start: start, end: end, speaker: speaker)
    }
}
