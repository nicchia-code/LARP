import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The library page of the main window (`main-window/Library`): the line with today's day and the
/// number of calls started today, the title, the search field and a grid of cards, one per call
/// that matches the search, the most recent first. While a proposal to record is shown, a dark banner
/// sits above the cards.
struct LibraryView: View {
    @Bindable var model: MainWindowModel
    @Query(sort: \Call.startedAt, order: .reverse) private var calls: [Call]
    @Query private var folders: [Folder]
    @Environment(CallLifecycle.self) private var lifecycle
    private let recorder = Recorder.shared
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if case .proposing(let app) = recorder.state {
                    ProposalBanner(
                        appName: app.name,
                        meeting: recorder.proposalMeeting,
                        // `user.ACCEPT_PROPOSAL`.
                        accept: { Task { await recorder.acceptProposal() } },
                        // `user.DISMISS_PROPOSAL`.
                        dismiss: { recorder.dismissProposal() })
                }
                content
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .larpSurface(.paper)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            // A cancelled panel is not an import.
            guard case .success(let url) = result else { return }
            Task<Void, Never> { _ = await lifecycle.importAudio(from: url) }
        }
    }

    // MARK: Header

    /// The folder shown, when the view is a folder that still exists.
    private var shownFolder: Folder? {
        guard case .folder(let id) = model.libraryView else { return nil }
        return folders.first { $0.id == id }
    }

    /// The calls the view is about: every call, or those of the folder shown.
    private var scopeCalls: [Call] {
        guard case .folder(let id) = model.libraryView else { return calls }
        return calls.filter { $0.folder?.id == id }
    }

    private var title: Text {
        switch model.libraryView {
        case .allCalls: Text("Tutto quello che è stato detto.")
        case .actions: Text("Azioni")
        case .bookmarks: Text("Segnalibri")
        case .folder: Text(verbatim: shownFolder?.name ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(verbatim: ArchiveFormat.todayLine(callsToday: ArchiveFormat.callsStarted(in: calls.map(\.startedAt))))
                title
                    .larpText(.pageTitle)
                    .foregroundStyle(LARPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            LARPSearchField(prompt: "Cerca parole, persone, decisioni", text: $model.searchText)
                .frame(width: 300)
                .padding(.bottom, 6)
        }
    }

    // MARK: Filters

    /// The row above the cards of all calls and of a folder: the filter chips ("Tutte", one per call
    /// app, "Manuali", "Importate", `user.FILTER_BY_APP`) and, on the right, the underlined text
    /// button "Importa file audio", which opens the system panel for audio files
    /// (`user.IMPORT_AUDIO`).
    private var filterRow: some View {
        let chips = LibraryFilter.chips(for: scopeCalls)
        return HStack(spacing: 8) {
            ForEach(chips, id: \.self) { filter in
                LARPChip(title: Self.title(of: filter), isSelected: model.appFilter == filter) {
                    model.filterByApp(filter)
                }
            }
            Spacer(minLength: 12)
            Button {
                isImporting = true
            } label: {
                Text("Importa file audio")
                    .font(LARPFont.inter(12, .semibold))
            }
            .buttonStyle(.larpLink)
        }
        // The call app of the chip chosen has no call any more: back to "Tutte".
        .onChange(of: chips, initial: true) {
            if !chips.contains(model.appFilter) { model.filterByApp(.all) }
        }
    }

    private static func title(of filter: AppFilter) -> LocalizedStringKey {
        switch filter {
        case .all: "Tutte"
        case .app(let name): LocalizedStringKey(name)
        case .manual: "Manuali"
        case .imported: "Importate"
        }
    }

    // MARK: Cards

    @ViewBuilder
    private var content: some View {
        switch model.libraryView {
        case .allCalls, .folder:
            VStack(alignment: .leading, spacing: 24) {
                filterRow
                cards
            }
        case .actions:
            // `user.SELECT_CALL`: the call of an item opens on its summary.
            ActionsLibraryView(groups: ActionListing.groups(of: calls, query: model.searchText)) { call in
                model.selectCall(call.id)
            }
        case .bookmarks:
            // `user.SELECT_BOOKMARK`.
            BookmarksLibraryView(groups: BookmarkListing.groups(of: calls, query: model.searchText)) { call, bookmark in
                model.selectBookmark(bookmark, of: call)
            }
        }
    }

    /// The cards of the calls that the filter shows and the search matches, the most recent first.
    @ViewBuilder
    private var cards: some View {
        let inScope = scopeCalls
        let shown = CallSearch.filter(LibraryFilter.apply(model.appFilter, to: inScope), query: model.searchText)
        if case .folder = model.libraryView, inScope.isEmpty {
            EmptyText(text: "Nessuna call in questa cartella")
        } else if inScope.isEmpty {
            EmptyNote(text: "Nessuna registrazione", detail: "Le call registrate compariranno qui.")
        } else if shown.isEmpty {
            EmptyNote(text: "Nessuna call trovata", detail: "Prova con altre parole.")
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16, alignment: .top)], spacing: 16) {
                ForEach(shown) { call in
                    // `user.SELECT_CALL`.
                    CallCard(call: call) { model.selectCall(call.id) }
                }
            }
        }
    }
}

/// An empty text, centred in the content area: 13 px `#5A5D55`.
private struct EmptyNote: View {
    let text: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Text(text).font(LARPFont.display(20, .semibold)).foregroundStyle(LARPColor.ink)
            Text(detail).font(LARPFont.inter(13)).foregroundStyle(LARPColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

/// An empty text, centred in the content area: 13 px `#5A5D55`.
struct EmptyText: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(LARPFont.inter(13))
            .foregroundStyle(LARPColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
    }
}
