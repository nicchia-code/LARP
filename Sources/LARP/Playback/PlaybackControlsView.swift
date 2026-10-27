import SwiftUI

/// Play/pause button, current and total time, and a progress bar that can be dragged.
struct PlaybackControlsView: View {
    let playback: PlaybackController
    /// Time under the thumb while it is being dragged.
    @State private var scrubTime: TimeInterval?

    var body: some View {
        if playback.canPlay {
            controls
        } else {
            Label("Audio non disponibile", systemImage: "speaker.slash")
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                playback.togglePlayPause()
            } label: {
                Label(
                    playback.state == .playing ? "Pausa" : "Riproduci",
                    systemImage: playback.state == .playing ? "pause.fill" : "play.fill"
                )
                .labelStyle(.iconOnly)
                .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)

            Text(ArchiveFormat.duration(shownTime))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { min(shownTime, sliderUpperBound) },
                    set: { scrubTime = $0 }
                ),
                in: 0...sliderUpperBound
            ) { isEditing in
                if !isEditing, let time = scrubTime {
                    playback.seek(to: time)
                    scrubTime = nil
                }
            }
            .disabled(playback.state == .stopped)
            .accessibilityLabel("Posizione")

            Text(ArchiveFormat.duration(playback.duration))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var shownTime: TimeInterval {
        scrubTime ?? playback.currentTime
    }

    private var sliderUpperBound: TimeInterval {
        max(playback.duration, 1)
    }
}
