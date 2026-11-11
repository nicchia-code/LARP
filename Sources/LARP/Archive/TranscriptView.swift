import SwiftData
import SwiftUI

/// The lines of the transcript of a call, in order: the dot of the colour of the speaker, the eyebrow
/// "<PARLANTE> <ora>" and the text. The line being heard has a `#EEF8B4` background and is kept in
/// the middle; a click on a line plays from its start; a click on a participant name renames it.
struct TranscriptView: View {
    let lines: [TranscriptLine]
    let playback: PlaybackController
    let onRenameParticipant: (Participant) -> Void
    /// The indexes of the lines that carry a bookmark (`BookmarkListing.bookmarkedLineIndexes`).
    let bookmarkedLines: Set<Int>
    /// The translation of the transcript: while it is shown, every line shows its translation in
    /// place of its text.
    var translation: TranscriptTranslation? = nil
    /// "Modifica testo" is on: the text of every line is editable in place.
    var isEditing = false
    /// `user.EDIT_LINE`: the text typed for a line.
    var onEditLine: (TranscriptLine, String) -> Void = { _, _ in }
    /// The text being looked for (`TranscriptFind`): its words are marked in the lines shown.
    var findQuery = ""
    /// The index of the found line being looked at (`TranscriptFind.currentLine`): outlined and
    /// scrolled to; the line being heard stays in the middle only while there is none.
    var foundLine: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.element.persistentModelID) { index, line in
                        TranscriptLineRow(
                            line: line,
                            shownText: translation?.text(of: line) ?? line.text,
                            isCurrent: playback.currentLineIndex == index,
                            isBookmarked: bookmarkedLines.contains(index),
                            onSelect: { playback.play(fromSentenceStart: line.start) },
                            onRenameParticipant: onRenameParticipant,
                            isEditing: isEditing,
                            onEditLine: { onEditLine(line, $0) },
                            findQuery: findQuery,
                            isFound: foundLine == index
                        )
                        .id(index)
                    }
                }
            }
            .onChange(of: playback.currentLineIndex) { _, index in
                // The line being heard is kept in the middle, except while a found line is looked at.
                guard let index, foundLine == nil else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
            }
            .onChange(of: foundLine) { _, index in
                guard let index else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }
}

private struct TranscriptLineRow: View {
    let line: TranscriptLine
    /// The text shown: the line's own, or its translation.
    let shownText: String
    let isCurrent: Bool
    /// The line is heard at the time of a bookmark of the call: "⌑ SEGNALIBRO" at the right of its eyebrow.
    let isBookmarked: Bool
    let onSelect: () -> Void
    let onRenameParticipant: (Participant) -> Void
    /// "Modifica testo" is on: the text is an editable field.
    let isEditing: Bool
    /// The text typed for the line, to be corrected.
    let onEditLine: (String) -> Void
    /// The text being looked for, whose words are marked.
    let findQuery: String
    /// The line is the found one being looked at: a 2 px ink outline.
    let isFound: Bool
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(line.speakerColor())
                .overlay { Circle().strokeBorder(LARPColor.ink, lineWidth: 1.5) }
                .frame(width: 11, height: 11)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    speaker
                    Text(verbatim: ArchiveFormat.clock(line.start))
                        .font(LARPFont.mono(11))
                        .tracking(0.06 * 11)
                        .foregroundStyle(LARPColor.textSecondary)
                    if isBookmarked {
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            Text(verbatim: "⌑")
                            Text("SEGNALIBRO")
                        }
                        .font(LARPFont.mono(11))
                        .tracking(0.08 * 11)
                        .foregroundStyle(LARPColor.textSecondary)
                    }
                }
                lineText
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCurrent ? LARPColor.currentLine : .clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if isFound { RoundedRectangle(cornerRadius: 10).strokeBorder(LARPColor.ink, lineWidth: 2) }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { onSelect() } }
        // "Fine": the text being typed is kept.
        .onChange(of: isEditing) { _, editing in if !editing { commit() } }
    }

    /// The text of the line: shown, or an editable field while "Modifica testo" is on, borderless with a
    /// `#E4E4DC` underline.
    @ViewBuilder
    private var lineText: some View {
        if isEditing {
            TextField("", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.ink)
                .lineSpacing(3)
                .focused($isFocused)
                .onSubmit(commit)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) { Rectangle().fill(LARPColor.border).frame(height: 1) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { draft = line.text }
                .onChange(of: isFocused) { _, focused in if !focused { commit() } }
        } else {
            Text(marked(shownText))
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `text` with the words found marked on a lime background.
    private func marked(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for range in TranscriptFind.ranges(of: findQuery, in: text) {
            if let lower = AttributedString.Index(range.lowerBound, within: attributed),
                let upper = AttributedString.Index(range.upperBound, within: attributed)
            {
                attributed[lower..<upper].backgroundColor = LARPColor.lime
            }
        }
        return attributed
    }

    /// `user.EDIT_LINE`: the new text goes to the call; an empty one leaves the line as it was.
    private func commit() {
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty, cleaned != line.text {
            onEditLine(cleaned)
        }
        draft = line.text
    }

    private var speakerLabel: some View {
        Text(verbatim: line.speakerName)
            .textCase(.uppercase)
            .font(LARPFont.mono(11))
            .tracking(0.08 * 11)
            .foregroundStyle(LARPColor.ink)
    }

    @ViewBuilder
    private var speaker: some View {
        if line.speakerKind == .participant, let participant = line.participant {
            Button { onRenameParticipant(participant) } label: { speakerLabel }
                .buttonStyle(.larpPlain)
                .help("Rinomina partecipante")
        } else {
            speakerLabel
        }
    }
}
