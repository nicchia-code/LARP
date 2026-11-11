import AppKit
import SwiftData
import SwiftUI

/// The page of one call (`main-window/Call shown`): at the top "‹ Archivio" and, on the right, "Esporta"
/// and the menu "…"; below, the eyebrow with the call app, the day and time and the duration, the
/// title in large type, the status of the call and the chips of its speakers; then two columns, the
/// summary on the left and the transcript on the right; at the bottom the playback bar.
struct CallDetailView: View {
    let call: Call
    let model: MainWindowModel
    private let playback = PlaybackController.shared

    @Environment(CallLifecycle.self) private var lifecycle
    @State private var titleDraft: String
    @FocusState private var titleIsFocused: Bool
    /// The number of the participant being renamed in its chip (`user.RENAME_PARTICIPANT`).
    @State private var renamingParticipant: Int?
    /// "Trova una parola": the text typed and what it finds in the lines shown.
    @State private var findText = ""
    @State private var find = TranscriptFind(typed: "", in: [], heard: nil)
    /// The copy button whose label reads "Copiata" for two seconds.
    @State private var copyMark: CopyMark?
    @State private var copyCount = 0
    @Query private var folders: [Folder]
    @State private var isConfirmingDelete = false
    @State private var isExporting = false
    @State private var isEditingText = false

    init(call: Call, model: MainWindowModel) {
        self.call = call
        self.model = model
        _titleDraft = State(initialValue: call.title ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            header
                .padding(.top, 8)
            columns
                .padding(.top, 20)
            if call.state != .recording {
                PlaybackControlsView(
                    playback: playback, lines: call.sortedLines, bookmarkTimes: BookmarkListing.times(of: call),
                    addBookmark: {
                        BookmarkShortcut.perform(recordingElapsedSeconds: nil, playback: playback, lifecycle: lifecycle)
                    }
                )
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .larpSurface(.paper)
        // `user.SELECT_CALL`: the audio of the call is loaded for playback.
        .onAppear { show() }
        .onChange(of: call.state) { show() }
        // `time.AUDIO_RETENTION_CHECK_DUE`: the audio of the call shown was deleted.
        .onChange(of: call.audioRemovedAfterDays) { show() }
        // The text can be corrected only while the call is ready.
        .onChange(of: call.state) { if call.state != .ready { isEditingText = false } }
        .onChange(of: call.lines.count) { updateTimeline() }
        .onChange(of: call.title) { titleDraft = call.title ?? "" }
        // The words found follow what the lines show: their own text or their translation.
        .onChange(of: findText) { updateFind() }
        .onChange(of: shownTexts) { updateFind() }
        // "Copiata" goes back to the label of the button after two seconds.
        .task(id: copyMark) {
            guard copyMark != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copyMark = nil }
        }
        .confirmationDialog("Eliminare la call?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            // `user.DELETE_CALL`.
            Button("Elimina", role: .destructive) { lifecycle.deleteCall(call) }
            // `user.CANCEL_DELETION`.
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'audio e la trascrizione verranno eliminati. L'operazione non si può annullare.")
        }
        .fileExporter(
            isPresented: $isExporting,
            document: MarkdownDocument(text: TranscriptExport.markdown(for: call)),
            contentType: MarkdownDocument.markdownType,
            defaultFilename: TranscriptExport.defaultFileName(for: call)
        ) { _ in }
    }

    // MARK: Top row

    private var topRow: some View {
        HStack(spacing: 10) {
            // `user.DESELECT_CALL`: back to the library, the audio is unloaded.
            Button("‹ Archivio") { model.showLibrary() }
                .buttonStyle(.larpLink)
            Spacer(minLength: 12)
            moveToFolderMenu
            // `user.COPY_SUMMARY`: only if the call has a summary.
            if let summary = TranscriptExport.summaryText(for: call) {
                Button {
                    copy(summary, as: .summary)
                } label: {
                    Text(copyMark?.target == .summary ? LocalizedStringKey("Copiata") : LocalizedStringKey("Copia sintesi"))
                }
                .buttonStyle(.larp(.outline))
            }
            // `user.EXPORT_CALL`: only if the call has lines.
            Button("Esporta") { isExporting = true }
                .buttonStyle(.larp(.dark))
                .disabled(call.lines.isEmpty)
            callMenu
        }
    }

    /// "Sposta in cartella", with the name of the current folder when there is one: a menu with the
    /// folders and "Nessuna cartella" (`user.MOVE_TO_FOLDER`).
    private var moveToFolderMenu: some View {
        Menu {
            ForEach(FolderName.sorted(folders)) { folder in
                Button {
                    lifecycle.moveCall(call, to: folder)
                } label: {
                    if call.folder?.id == folder.id {
                        Label {
                            Text(verbatim: folder.name)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(verbatim: folder.name)
                    }
                }
            }
            if !folders.isEmpty { Divider() }
            Button("Nessuna cartella") { lifecycle.moveCall(call, to: nil) }
                .disabled(call.folder == nil)
        } label: {
            if let folder = call.folder {
                Text(verbatim: L10n.format("Sposta in cartella · %@", folder.name))
            } else {
                Text("Sposta in cartella")
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.larp(.outline))
        .fixedSize()
    }

    /// The menu "…": "Rifinisci testo", "Ripristina originale" and "Elimina", each enabled only when
    /// the call allows it.
    private var callMenu: some View {
        Menu {
            Button("Rifinisci testo") { lifecycle.refineTranscript(call) }
                .disabled(!lifecycle.canRefine(call))
            Button("Ripristina originale") { lifecycle.restoreTranscript(call) }
                .disabled(!lifecycle.canRestore(call))
            // `user.ASK_TO_DELETE`: only when the call is not being recorded.
            Button("Elimina", role: .destructive) { isConfirmingDelete = true }
                .disabled(!lifecycle.canDelete(call))
        } label: {
            Text(verbatim: "…")
                .frame(minWidth: 18)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.larp(.outline))
        .fixedSize()
        .accessibilityLabel("Altre azioni")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(verbatim: eyebrow)
            TextField("", text: $titleDraft, prompt: Text(call.displayTitle), axis: .vertical)
                .textFieldStyle(.plain)
                .larpText(.callTitle)
                .foregroundStyle(LARPColor.ink)
                .lineLimit(1...2)
                .focused($titleIsFocused)
                .disabled(!lifecycle.canRename(call))
                .onSubmit(commitTitle)
                .onChange(of: titleIsFocused) { _, isFocused in
                    if !isFocused { commitTitle() }
                }
            if let status = lifecycle.statusLabel(of: call) {
                Text(verbatim: status)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
            }
            SpeakerChipsRow(call: call, renaming: $renamingParticipant)
        }
    }

    /// "<app di call> · <giorno e ora> · <durata>", the duration not while recording.
    private var eyebrow: String {
        var parts = [call.appLabel(), ArchiveFormat.dayAndTime(call.startedAt)]
        if call.state != .recording { parts.append(ArchiveFormat.cardDuration(call.duration)) }
        return parts.joined(separator: " · ")
    }

    private func commitTitle() {
        guard titleDraft != (call.title ?? "") else { return }
        lifecycle.renameCall(call, to: titleDraft)
        titleDraft = call.title ?? ""
    }

    // MARK: Columns

    /// About 55 % and 45 %, 24 px apart.
    private var columns: some View {
        GeometryReader { geometry in
            let available = geometry.size.width - 24
            HStack(alignment: .top, spacing: 24) {
                tabs
                    .frame(width: available * 0.55)
                transcriptCard
                    .frame(width: available * 0.45)
            }
            .frame(height: geometry.size.height)
        }
    }

    /// The tabs "Sintesi", "Le mie note" and "Segnalibri" (`user.SHOW_SUMMARY`, `user.SHOW_NOTES`,
    /// `user.SHOW_BOOKMARKS`); "Sintetizza" / "Rigenera" sit on the right of the tabs while the
    /// summary is shown.
    private var tabs: some View {
        VStack(alignment: .leading, spacing: 16) {
            CallTabBar(selection: Binding(get: { model.callTab }, set: { model.showTab($0) })) {
                // `user.SUMMARIZE_CALL`: passed to the summary of the call.
                if model.callTab == .summary, lifecycle.canSummarize(call) {
                    Button(call.summary == nil ? LocalizedStringKey("Sintetizza") : LocalizedStringKey("Rigenera")) {
                        lifecycle.summarize(call)
                    }
                    .buttonStyle(.larp(.outline))
                }
            }
            switch model.callTab {
            case .summary:
                CallSummaryView(call: call, playback: playback)
            case .notes:
                ScrollView { CallNotesTab(call: call, playback: playback) }
            case .bookmarks:
                ScrollView { CallBookmarksTab(call: call, playback: playback) }
            }
            // `user.ASK_CALL`: the questions about the call and the field to ask them.
            CallQuestionsView(call: call, questions: model.questions)
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Trascrizione")
                    .larpText(.sectionHeading)
                    .foregroundStyle(LARPColor.ink)
                Spacer(minLength: 8)
                if !call.lines.isEmpty {
                    TranscriptFindField(
                        text: $findText, find: find,
                        previous: { find.previous() }, next: { find.next() }
                    )
                    .frame(maxWidth: 260)
                }
            }
            // `user.TRANSLATE_TRANSCRIPT`, `user.SHOW_ORIGINAL`.
            if !call.lines.isEmpty {
                TranscriptTranslationBar(call: call, translation: model.translation)
            }
            transcript
            textEditingLink
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LARPColor.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(LARPColor.border, lineWidth: 1) }
    }

    /// "Modifica testo", only when the call is ready and has lines (while it is on the text of every
    /// line is editable in place and the link reads "Fine"), and "Copia trascrizione"
    /// (`user.COPY_TRANSCRIPT`), under the lines, only when the call has lines.
    @ViewBuilder
    private var textEditingLink: some View {
        if !call.lines.isEmpty {
            HStack(spacing: 16) {
                if lifecycle.canEditLines(of: call) {
                    Button {
                        isEditingText.toggle()
                    } label: {
                        Text(isEditingText ? LocalizedStringKey("Fine") : LocalizedStringKey("Modifica testo"))
                            .font(LARPFont.inter(12))
                    }
                    .buttonStyle(.larpLink)
                }
                Button {
                    copy(TranscriptExport.transcriptText(for: call), as: .transcript)
                } label: {
                    Text(copyMark?.target == .transcript ? LocalizedStringKey("Copiata") : LocalizedStringKey("Copia trascrizione"))
                        .font(LARPFont.inter(12))
                }
                .buttonStyle(.larpLink)
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyTranscriptText: LocalizedStringKey {
        call.state == .ready ? "Nessuna trascrizione" : "Trascrizione non ancora disponibile"
    }

    @ViewBuilder
    private var transcript: some View {
        let lines = call.sortedLines
        if lines.isEmpty {
            Text(emptyTranscriptText)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TranscriptView(
                lines: lines, playback: playback, onRenameParticipant: { participant in
                    // `user.RENAME_PARTICIPANT`: the chip of the participant becomes a field, only
                    // while the call is ready.
                    guard CallStateMachine.target(from: call.state, on: .renameParticipant) != nil else { return }
                    renamingParticipant = participant.number
                }, bookmarkedLines: BookmarkListing.bookmarkedLineIndexes(of: call), translation: model.translation,
                isEditing: isEditingText,
                // `user.EDIT_LINE`.
                onEditLine: { line, text in model.editLine(line, of: call, to: text, lifecycle: lifecycle) },
                findQuery: find.query, foundLine: find.currentLine)
        }
    }

    // MARK: Playback

    /// Loads the audio of the call into the playback (stopping any other call's) and its lines' times.
    private func show() {
        playback.show(call)
        updateTimeline()
    }

    private func updateTimeline() {
        playback.setTimeline(call.sortedLines.map { LineTiming(start: $0.start, end: $0.end) })
    }

    // MARK: Find and copy

    /// The text of every line as shown: its own, or its translation.
    private var shownTexts: [String] {
        call.sortedLines.map { model.translation.text(of: $0) ?? $0.text }
    }

    /// The lines that "Trova una parola" finds, the first one after the line being heard being looked
    /// at first.
    private func updateFind() {
        find = TranscriptFind(typed: findText, in: shownTexts, heard: playback.currentLineIndex)
    }

    /// `user.COPY_SUMMARY`, `user.COPY_TRANSCRIPT`: the text goes to the clipboard and "Copiata" shows
    /// for two seconds; the tab shown does not change.
    private func copy(_ text: String?, as target: CopyTarget) {
        guard let text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyCount += 1
        copyMark = CopyMark(target: target, serial: copyCount)
    }

    private enum CopyTarget { case summary, transcript }

    private struct CopyMark: Hashable {
        let target: CopyTarget
        let serial: Int
    }
}
