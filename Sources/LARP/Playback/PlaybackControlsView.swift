import SwiftUI

/// The playback bar at the bottom of the page of a call: an ink bar, 64 px high, with the play/pause
/// button, the time reached, the timeline of the transcript lines coloured by speaker with the
/// bookmarks ticking above it, the length of the audio and the "Segnalibro" button. Without audio it
/// says so in place of the timeline and the buttons are disabled.
struct PlaybackControlsView: View {
    let playback: PlaybackController
    /// The transcript lines of the call, sorted by start: one timeline segment each.
    let lines: [TranscriptLine]
    /// The times of the bookmarks of the call: small lime ticks above the timeline.
    let bookmarkTimes: [TimeInterval]
    /// `user.ADD_BOOKMARK` from the bar: a bookmark at the time reached.
    let addBookmark: () -> Void
    /// Time under the pointer while the timeline is being clicked or dragged.
    @State private var scrubTime: TimeInterval?

    var body: some View {
        HStack(spacing: 14) {
            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LARPColor.ink)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(LARPColor.lime))
                    .opacity(playback.canPlay ? 1 : 0.4)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!playback.canPlay)
            .accessibilityLabel(playback.state == .playing ? "Pausa" : "Riproduci")

            if playback.canPlay {
                Text(ArchiveFormat.duration(shownTime))
                    .font(LARPFont.mono(12))
                    .foregroundStyle(.white)
                timeline
                Text(ArchiveFormat.duration(playback.duration))
                    .font(LARPFont.mono(12))
                    .foregroundStyle(LARPColor.textMuted)
            } else {
                Text(unavailableText)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textMuted)
                Spacer(minLength: 0)
            }

            // `user.ADD_BOOKMARK`: marks the time reached, while playing or paused.
            Button(action: addBookmark) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LARPColor.textOnDark)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(LARPColor.darkCard))
                    .opacity(playback.canPlay && playback.state != .stopped ? 1 : 0.4)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!playback.canPlay || playback.state == .stopped)
            .accessibilityLabel("Segnalibro")
            .help("Segnalibro")

            HStack(spacing: 8) {
                // `user.CHANGE_SPEED`: the next speed, saved and applied at once.
                optionChip(
                    PlaybackOptions.label(for: playback.options.speed), foreground: .white,
                    border: LARPColor.darkBorder, font: LARPFont.mono(12), action: playback.changeSpeed
                )
                .accessibilityLabel("Velocità")
                .accessibilityValue(PlaybackOptions.label(for: playback.options.speed))

                // `user.TURN_ON_SKIP_SILENCE` / `user.TURN_OFF_SKIP_SILENCE`.
                let skipping = playback.options.skipSilence
                optionChip(
                    L10n.string("Salta i silenzi"), foreground: skipping ? LARPColor.lime : LARPColor.textMuted,
                    border: skipping ? LARPColor.lime : LARPColor.darkBorder, font: LARPFont.inter(12, .medium),
                    action: { playback.options.setSkipSilence(!skipping) }
                )
                .accessibilityAddTraits(skipping ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 18).fill(LARPColor.ink))
        .environment(\.colorScheme, .dark)
    }

    private var shownTime: TimeInterval {
        scrubTime ?? playback.currentTime
    }

    /// What the bar says in place of the timeline: that the retention deleted the audio, or that there
    /// is none to play.
    private var unavailableText: String {
        guard let days = playback.audioRemovedAfterDays else { return L10n.string("Audio non disponibile") }
        return L10n.format("Audio eliminato dopo %lld giorni", days)
    }

    /// A chip of the bar: 32 px high, an outline in `border` and its text in `foreground`.
    private func optionChip(
        _ title: String, foreground: Color, border: Color, font: Font, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .overlay { Capsule().strokeBorder(border, lineWidth: 1) }
                .contentShape(Capsule())
        }
        .buttonStyle(.larpPlain)
        .larpFocusOutline(cornerRadius: 16)
    }

    /// One segment per line, the parts heard in full colour and the rest at 45 %, and a white bar at
    /// the time reached. A click or a drag moves the position (`user.SEEK`) when released.
    private var timeline: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let segments = lines.map(TimelineSegment.init)
            let frames = PlaybackTimelineGeometry.frames(
                of: segments, duration: playback.duration, width: width)
            let playheadX = PlaybackTimelineGeometry.playheadX(
                time: shownTime, duration: playback.duration, width: width)
            // The bookmarks tick above the segments, which take the rest of the height.
            let tickHeight: CGFloat = 6
            let barTop = tickHeight
            let barHeight = height - tickHeight
            Canvas { context, _ in
                let shapes = zip(segments, frames).map { segment, frame in
                    (
                        Path(
                            roundedRect: CGRect(x: frame.x, y: barTop, width: frame.width, height: barHeight),
                            cornerRadius: 4),
                        SpeakerPalette.color(
                            kind: segment.speakerKind, participantNumber: segment.participantNumber, onDark: true)
                    )
                }
                for (path, color) in shapes {
                    context.fill(path, with: .color(color.opacity(0.45)))
                }
                context.drawLayer { heard in
                    heard.clip(to: Path(CGRect(x: 0, y: 0, width: playheadX, height: height)))
                    for (path, color) in shapes {
                        heard.fill(path, with: .color(color))
                    }
                }
                context.fill(
                    Path(
                        CGRect(
                            x: min(max(playheadX - 1, 0), max(width - 2, 0)), y: barTop, width: 2, height: barHeight)),
                    with: .color(.white))
                for time in bookmarkTimes {
                    let x = PlaybackTimelineGeometry.playheadX(time: time, duration: playback.duration, width: width)
                    context.fill(
                        Path(
                            roundedRect: CGRect(
                                x: min(max(x - 1, 0), max(width - 2, 0)), y: 0, width: 2, height: tickHeight - 1),
                            cornerRadius: 1),
                        with: .color(LARPColor.lime))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard playback.state != .stopped else { return }
                        scrubTime = PlaybackTimelineGeometry.time(
                            atX: value.location.x, duration: playback.duration, width: width)
                    }
                    .onEnded { value in
                        defer { scrubTime = nil }
                        guard playback.state != .stopped else { return }
                        playback.seek(
                            to: PlaybackTimelineGeometry.time(
                                atX: value.location.x, duration: playback.duration, width: width))
                    }
            )
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel("Posizione")
    }
}
