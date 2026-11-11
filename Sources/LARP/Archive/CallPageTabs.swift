import SwiftUI

/// The tabs of the page of a call (states of **Call shown** in the `main-window` machine): the page
/// opens on `.summary`; `user.SHOW_SUMMARY`, `user.SHOW_NOTES` and `user.SHOW_BOOKMARKS` switch
/// between them.
enum CallPageTab: CaseIterable, Identifiable, Sendable {
    case summary
    case notes
    case bookmarks

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .summary: "Sintesi"
        case .notes: "Le mie note"
        case .bookmarks: "Segnalibri"
        }
    }
}

/// The tabs over a 1 px ink line, in Bricolage Grotesque 18 px: the selected one ink with a 3 px lime
/// underline, the others `#5A5D55`; `trailing` sits on the right ("Sintetizza" / "Rigenera" while the
/// summary is shown).
struct CallTabBar<Trailing: View>: View {
    @Binding var selection: CallPageTab
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            ForEach(CallPageTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.title)
                        .font(LARPFont.display(18, .semibold))
                        .foregroundStyle(selection == tab ? LARPColor.ink : LARPColor.textSecondary)
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) {
                            if selection == tab {
                                Rectangle().fill(LARPColor.lime).frame(height: 3)
                            }
                        }
                }
                .buttonStyle(.larpPlain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
            Spacer(minLength: 12)
            trailing
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(LARPColor.ink).frame(height: 1)
        }
    }
}

// MARK: - Bookmarks

/// "Segnalibri": the bookmarks of a call in order of time, each with its time, the text of the
/// transcript line at that time and a way to delete it; a click plays the audio from it
/// (`user.SELECT_BOOKMARK`). Without bookmarks it says "Nessun segnalibro".
struct CallBookmarksTab: View {
    let call: Call
    let playback: PlaybackController
    @Environment(CallLifecycle.self) private var lifecycle

    var body: some View {
        let rows = BookmarkListing.rows(of: call)
        if rows.isEmpty {
            Text("Nessun segnalibro")
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    CallBookmarkRow(
                        row: row,
                        play: { playback.selectBookmark(at: row.time, of: call) },
                        delete: { lifecycle.deleteBookmark(row.bookmark) })
                    if row.id != rows.last?.id { LARPDivider() }
                }
            }
        }
    }
}

private struct CallBookmarkRow: View {
    let row: BookmarkRow
    let play: () -> Void
    let delete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: play) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    ClockChip(seconds: row.time)
                    Text(row.lineText ?? "")
                        .font(LARPFont.inter(15))
                        .foregroundStyle(LARPColor.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.larpPlain)
            RowDeleteButton(label: "Elimina segnalibro", action: delete)
                .opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 12)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Notes

/// "Le mie note": one row per note in order of time, with its time in a chip (none without time), its
/// text editable in place and a way to delete it; at the bottom the field "Scrivi una nota…" adds a note
/// with Return, at the time reached while the audio of this call plays or is paused, without time
/// otherwise. Without notes it says "Nessuna nota".
struct CallNotesTab: View {
    let call: Call
    let playback: PlaybackController
    @Environment(CallLifecycle.self) private var lifecycle
    @State private var draft = ""

    var body: some View {
        let notes = call.sortedNotes
        VStack(alignment: .leading, spacing: 16) {
            if notes.isEmpty {
                Text("Nessuna nota")
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(notes) { note in
                        CallNoteRow(
                            note: note,
                            commit: { lifecycle.editNote(note, to: $0) },
                            delete: { lifecycle.deleteNote(note) })
                        if note.id != notes.last?.id { LARPDivider() }
                    }
                }
            }
            LARPTextField(prompt: "Scrivi una nota…", text: $draft, onSubmit: add)
        }
    }

    /// `user.ADD_NOTE` in the notes of the page.
    private func add() {
        let listening = playback.callID == call.id && playback.state != .stopped
        if lifecycle.addNote(to: call, text: draft, at: listening ? playback.currentTime : nil) != nil {
            draft = ""
        }
    }
}

private struct CallNoteRow: View {
    let note: Note
    let commit: (String) -> Void
    let delete: () -> Void
    @State private var text: String
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    init(note: Note, commit: @escaping (String) -> Void, delete: @escaping () -> Void) {
        self.note = note
        self.commit = commit
        self.delete = delete
        _text = State(initialValue: note.text)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let time = note.time {
                ClockChip(seconds: time)
            }
            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(LARPFont.inter(15))
                .foregroundStyle(LARPColor.ink)
                .focused($isFocused)
                .onSubmit(save)
                .frame(maxWidth: .infinity, alignment: .leading)
            RowDeleteButton(label: "Elimina nota", action: delete)
                .opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 12)
        .onHover { isHovering = $0 }
        .onChange(of: isFocused) { _, focused in if !focused { save() } }
        .onChange(of: note.text) { _, new in if !isFocused { text = new } }
    }

    /// `user.EDIT_NOTE`: a new text replaces the old one, an empty one deletes the note.
    private func save() {
        guard text != note.text else { return }
        commit(text)
    }
}
