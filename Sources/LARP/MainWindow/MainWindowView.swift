import SwiftData
import SwiftUI

/// The content of the main window (machine `main-window`): a dark sidebar on the left and, beside
/// it, one page at a time: the library of the recorded calls, the page of one call, or the
/// settings, which take the whole window and draw their own sidebar.
struct MainWindowView: View {
    let model: MainWindowModel

    var body: some View {
        Group {
            switch model.page {
            case .settings:
                // `user.CLOSE_SETTINGS`: back to the library.
                SettingsPage(close: model.closeSettings)
            case .library, .call:
                HStack(spacing: 0) {
                    MainSidebar(model: model)
                    page
                }
            }
        }
        .larpSurface(.paper)
        .frame(minWidth: 900, minHeight: 600)
        .ignoresSafeArea()
        // `call.DELETED`: when the call shown is gone, the library comes back.
        .onReceive(NotificationCenter.default.publisher(for: .callDeleted)) { notification in
            if let id = notification.callID { model.callDeleted(id) }
        }
        // `call.TRANSCRIPT_REFINED`: a translation of the call shown is dropped.
        .onReceive(NotificationCenter.default.publisher(for: .transcriptRefined)) { notification in
            if let id = notification.callID { model.transcriptRefined(id) }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .call(let id):
            CallPageLoader(callID: id, model: model)
                .id(id)
        case .library, .settings:
            LibraryView(model: model)
        }
    }
}

/// The page of a call, looked up by its identifier: when the call is gone (deleted elsewhere) the
/// window goes back to the library.
private struct CallPageLoader: View {
    let callID: UUID
    let model: MainWindowModel
    @Query private var calls: [Call]

    init(callID: UUID, model: MainWindowModel) {
        self.callID = callID
        self.model = model
        _calls = Query(filter: #Predicate<Call> { $0.id == callID })
    }

    var body: some View {
        if let call = calls.first {
            CallDetailView(call: call, model: model)
        } else {
            Color.clear.onAppear { model.showLibrary() }
        }
    }
}

/// The sidebar of the library: the LARP mark, "Nuova registrazione", the views of the library and,
/// at the bottom, "Impostazioni".
struct MainSidebar: View {
    let model: MainWindowModel
    private let recorder = Recorder.shared

    var body: some View {
        LARPSidebar {
            VStack(alignment: .leading, spacing: 24) {
                LarpWordmark()
                    .padding(.horizontal, 4)
                newRecording
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            SidebarItem(
                                title: "Tutte le call",
                                isSelected: model.page != .settings && model.libraryView == .allCalls
                            ) {
                                // `user.SHOW_ALL_CALLS`.
                                model.showAllCalls()
                            }
                            SidebarItem(
                                title: "Azioni",
                                isSelected: model.page != .settings && model.libraryView == .actions
                            ) {
                                // `user.SHOW_ACTIONS_VIEW`.
                                model.showActionsView()
                            }
                            SidebarItem(
                                title: "Segnalibri",
                                isSelected: model.page != .settings && model.libraryView == .bookmarks
                            ) {
                                // `user.SHOW_BOOKMARKS_VIEW`.
                                model.showBookmarksView()
                            }
                        }
                        SidebarFolders(model: model)
                    }
                }
                .scrollIndicators(.hidden)
                Spacer(minLength: 0)
                SidebarItem(title: "Impostazioni", isSelected: false) {
                    // `user.OPEN_SETTINGS`.
                    MainWindowController.shared.openSettings()
                }
            }
        }
    }

    /// "Nuova registrazione": starts a recording by hand as "Registra" does in the popover, without
    /// changing the page; available only while nothing is recorded and no proposal is shown.
    private var newRecording: some View {
        Button {
            Task { await recorder.startRecording() }
        } label: {
            HStack(spacing: 8) {
                Text("Nuova registrazione")
                Spacer(minLength: 0)
                if let keys = ShortcutsController.shared.display(for: .record) {
                    ShortcutKeys(text: keys, style: .plain(LARPColor.ink))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(LARPColor.lime, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.larpPlain)
        .font(LARPFont.inter(13, .semibold))
        .foregroundStyle(LARPColor.ink)
        .disabled(!recorder.canStartRecording)
    }
}

/// The LARP mark with "LARP" in Bricolage Grotesque 20 px bold.
struct LarpWordmark: View {
    var markSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 10) {
            LarpMark(size: markSize)
            Text(verbatim: "LARP")
                .larpText(.wordmark)
                .foregroundStyle(.white)
        }
    }
}

/// An item of a sidebar: 13 px `#E9EAE3`, 8 × 10 px padding, radius 8; the selected one is
/// `#23251F` with lime semibold text.
struct SidebarItem: View {
    let title: Text
    let isSelected: Bool
    let action: () -> Void

    init(title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(title)
        self.isSelected = isSelected
        self.action = action
    }

    /// An item whose title is not looked up in the catalog: the name of a folder.
    init(verbatim title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .font(LARPFont.inter(13, isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? LARPColor.lime : LARPColor.textOnDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? LARPColor.darkSelected : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.larpPlain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
