import SwiftUI

/// The pill: ink, 64 px high, radius 32, about 390 px wide. The elapsed time with a red dot (grey
/// and "In pausa" while paused), a live waveform of about 20 lime bars, then three round 44 px
/// buttons. A click on the time or the waveform opens the live window.
struct RecordingPillView: View {
    let controller: RecordingViewController
    let recorder: Recorder

    var body: some View {
        let isPaused = recorder.isPaused
        HStack(spacing: 12) {
            Button {
                recorder.openLiveWindow()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isPaused ? LARPColor.textMuted : LARPColor.recording)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Recorder.formatElapsed(recorder.elapsedSeconds))
                            .font(LARPFont.mono(16))
                            .foregroundStyle(.white)
                        if isPaused {
                            Text("In pausa")
                                .font(LARPFont.inter(11, .medium))
                                .foregroundStyle(LARPColor.textMuted)
                        }
                    }
                    LiveWaveform(levels: bars(isPaused: isPaused), color: LARPColor.lime, barWidth: 3, gap: 2)
                        .frame(height: 28)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.larpPlain)
            .accessibilityLabel(Text(LocalizedStringKey(isPaused ? "In pausa" : "Registrazione in corso")))
            .accessibilityHint(Text("Apri finestra dal vivo"))

            HStack(spacing: 8) {
                PillButton(label: "Segnalibro", fill: LARPColor.darkCard, action: controller.addBookmark) {
                    Image(systemName: "bookmark.fill").font(.system(size: 15)).foregroundStyle(.white)
                }
                PillButton(
                    label: isPaused ? "Riprendi" : "Pausa", fill: LARPColor.darkCard, action: controller.togglePause
                ) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill").font(.system(size: 15)).foregroundStyle(.white)
                }
                PillButton(label: "Ferma", fill: .white, action: controller.stopRecording) {
                    RoundedRectangle(cornerRadius: 3).fill(LARPColor.ink).frame(width: 14, height: 14)
                }
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 10)
        .frame(width: AppKitRecordingSurfaces.pillSize.width, height: AppKitRecordingSurfaces.pillSize.height)
        .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 32))
        .larpAppearance(dark: true)
    }

    /// The waveform stays flat while paused.
    private func bars(isPaused: Bool) -> [Double] {
        isPaused ? Array(repeating: 0, count: LiveRecordingState.pillBarCount) : controller.state.recentBars
    }
}

/// A round 44 px button of the pill: its name is the tooltip and the accessibility label.
private struct PillButton<Glyph: View>: View {
    let label: LocalizedStringKey
    let fill: Color
    let action: () -> Void
    @ViewBuilder let glyph: Glyph

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.larpPlain)
        .help(label)
        .accessibilityLabel(Text(label))
    }
}
