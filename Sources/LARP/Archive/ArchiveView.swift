import SwiftData
import SwiftUI

/// Content of the archive window (machine `main-window`): on the left a search
/// field and the list of calls, newest first; on the right the selected call.
struct ArchiveView: View {
    @Query(sort: \Call.startedAt, order: .reverse) private var calls: [Call]
    @Environment(CallLifecycle.self) private var lifecycle

    @State private var searchText = ""
    @State private var selectedCallID: UUID?
    @State private var playback = PlaybackController()
    @State private var isConfirmingDelete = false
    @State private var isExporting = false

    var body: some View {
        NavigationSplitView {
            list
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 400)
        } detail: {
            detail
        }
        .frame(minWidth: 760, minHeight: 420)
        .toolbar { toolbar }
        .confirmationDialog(
            "Eliminare la call?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive, action: deleteSelectedCall)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'audio e la trascrizione verranno eliminati. L'operazione non si può annullare.")
        }
        .fileExporter(
            isPresented: $isExporting,
            document: MarkdownDocument(text: selectedCall.map(TranscriptExport.markdown(for:)) ?? ""),
            contentType: MarkdownDocument.markdownType,
            defaultFilename: selectedCall.map(TranscriptExport.defaultFileName(for:)) ?? "Call"
        ) { _ in }
        // `user.CLOSE_WINDOW`: closing the window stops the playback.
        .onDisappear { playback.stop() }
        // `call.DELETED`: the call shown is gone.
        .onReceive(NotificationCenter.default.publisher(for: .callDeleted)) { notification in
            if notification.callID == selectedCallID { selectedCallID = nil }
        }
        .onChange(of: selectedCall == nil) { _, isGone in
            if isGone {
                selectedCallID = nil
                playback.show(nil)
            }
        }
    }

    // MARK: Parts

    private var selectedCall: Call? {
        guard let selectedCallID else { return nil }
        return calls.first { $0.id == selectedCallID }
    }

    private var list: some View {
        let shown = CallSearch.filter(calls, query: searchText)
        return List(shown, selection: $selectedCallID) { call in
            CallRow(call: call)
                .tag(call.id)
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Cerca")
        .overlay {
            if calls.isEmpty {
                ContentUnavailableView(
                    "Nessuna registrazione",
                    systemImage: "waveform",
                    description: Text("Le call registrate compariranno qui.")
                )
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let call = selectedCall {
            CallDetailView(call: call, playback: playback)
                .id(call.id)
        } else {
            ContentUnavailableView(
                "Nessuna call selezionata",
                systemImage: "waveform",
                description: Text("Scegli una call dall'elenco.")
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Esporta…", systemImage: "square.and.arrow.up") {
                isExporting = true
            }
            .disabled(selectedCall?.lines.isEmpty ?? true)

            Button("Elimina", systemImage: "trash") {
                isConfirmingDelete = true
            }
            .disabled(selectedCall.map { !lifecycle.canDelete($0) } ?? true)
        }
    }

    // MARK: Actions

    private func deleteSelectedCall() {
        guard let call = selectedCall else { return }
        lifecycle.deleteCall(call)
        selectedCallID = nil
    }
}
