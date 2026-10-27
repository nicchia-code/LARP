import SwiftData
import SwiftUI

/// The transcript of a call: one row per line with the speaker, the start time as
/// `mm:ss` and the text. The line being heard is highlighted and kept in view; a
/// click on a line plays from its start; a click on a participant name renames it.
struct TranscriptView: View {
    let lines: [TranscriptLine]
    let playback: PlaybackController
    let onRenameParticipant: (Participant) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.element.persistentModelID) { index, line in
                        TranscriptLineRow(
                            line: line,
                            isCurrent: playback.currentLineIndex == index,
                            onSelect: { playback.play(fromSentenceStart: line.start) },
                            onRenameParticipant: onRenameParticipant
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: playback.currentLineIndex) { _, index in
                guard let index else { return }
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }
}

private struct TranscriptLineRow: View {
    let line: TranscriptLine
    let isCurrent: Bool
    let onSelect: () -> Void
    let onRenameParticipant: (Participant) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            speaker
                .fontWeight(.semibold)
                .frame(width: 110, alignment: .leading)
            Text(ArchiveFormat.clock(line.start))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(line.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var speaker: some View {
        if line.speakerKind == .participant, let participant = line.participant {
            Button(line.speakerName) { onRenameParticipant(participant) }
                .buttonStyle(.plain)
                .help("Rinomina partecipante")
        } else {
            Text(line.speakerName)
        }
    }
}
