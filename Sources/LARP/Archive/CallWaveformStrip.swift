import SwiftUI

/// The waveform of a call on its card: an ink strip 44 px high, radius 10, with 10 px side padding, and
/// the 44 bars coloured by speaker (as wide as the strip allows, 4 px at most, 2 px apart); the bars of
/// a call without lines are `#6B6E64`.
struct CallWaveformStrip: View {
    let bars: [WaveformBar]
    /// The call has transcript lines.
    let hasLines: Bool

    static let height: CGFloat = 44
    static let sidePadding: CGFloat = 10
    static let maxBarWidth: CGFloat = 4
    static let gap: CGFloat = 2
    /// The bars of a call without lines.
    static let noLinesColor = Color(hex: 0x6B6E64)

    var body: some View {
        GeometryReader { proxy in
            let count = max(bars.count, 1)
            let available = proxy.size.width - 2 * Self.sidePadding
            let width = min(Self.maxBarWidth, max((available - Self.gap * CGFloat(count - 1)) / CGFloat(count), 1))
            WaveformBars(bars: shown, barWidth: width, gap: Self.gap, floor: 4)
                .frame(
                    width: width * CGFloat(count) + Self.gap * CGFloat(count - 1) + 0.5, height: proxy.size.height - 12
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Self.height)
        .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 10))
    }

    private var shown: [WaveformBars.Bar] {
        bars.map { bar in
            WaveformBars.Bar(level: bar.level, color: color(of: bar.speaker))
        }
    }

    private func color(of speaker: WaveformSpeaker) -> Color {
        guard hasLines else { return Self.noLinesColor }
        switch speaker {
        case .me: return SpeakerPalette.color(kind: .me, participantNumber: nil, onDark: true)
        case .participant(let number): return SpeakerPalette.color(kind: .participant, participantNumber: number, onDark: true)
        case .others: return SpeakerPalette.color(kind: .others, participantNumber: nil, onDark: true)
        case .silence: return LARPColor.darkBorder
        }
    }
}
