import SwiftUI

/// Waveform as rounded bars 3–4 px wide with 2–3 px gaps, coloured by speaker, idle bars `#3A3C36`
/// on dark.
struct WaveformBars: View {
    struct Bar: Equatable, Sendable {
        /// 0 (the floor) to 1 (full height).
        var level: Double
        var color: Color
    }

    let bars: [Bar]
    var barWidth: CGFloat = 3
    var gap: CGFloat = 2
    /// The height of a bar at level 0, so that silence still shows.
    var floor: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let step = barWidth + gap
            let count = min(bars.count, max(Int((size.width + gap) / step), 0))
            for index in 0..<count {
                let bar = bars[index]
                let height = max(floor, size.height * min(max(bar.level, 0), 1))
                let rect = CGRect(
                    x: CGFloat(index) * step, y: (size.height - height) / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(bar.color))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A waveform that moves with a level history (the pill and the live window of a recording).
/// Nothing moves when the Mac asks to reduce motion: the bars stay as they were when it showed.
struct LiveWaveform: View {
    /// The levels, 0 to 1, oldest first; the last ones are drawn when there are more than fit.
    let levels: [Double]
    var color: Color
    var idleColor: Color = LARPColor.darkBorder
    var barWidth: CGFloat = 3
    var gap: CGFloat = 2
    var floor: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frozen: [Double]?

    var body: some View {
        let shown = reduceMotion ? (frozen ?? levels) : levels
        WaveformBars(
            bars: shown.map { WaveformBars.Bar(level: $0, color: $0 > 0 ? color : idleColor) },
            barWidth: barWidth, gap: gap, floor: floor
        )
        .onAppear { if reduceMotion { frozen = levels } }
        .onChange(of: reduceMotion) { _, reduced in frozen = reduced ? levels : nil }
    }
}
