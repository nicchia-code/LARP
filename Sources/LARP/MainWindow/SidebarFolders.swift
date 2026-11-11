import SwiftData
import SwiftUI

/// The group "Cartelle" of the sidebar (`main-window`, `folder`): the eyebrow, the folders in
/// alphabetical order and "+ Nuova cartella", which becomes a text field on the dark background while
/// the name is typed: Return creates the folder (`user.CREATE_FOLDER`), Esc cancels. A click on a
/// folder shows its calls (`user.SHOW_FOLDER`); its context menu renames it (`user.RENAME_FOLDER`) or
/// deletes it (`user.DELETE_FOLDER`).
struct SidebarFolders: View {
    let model: MainWindowModel
    @Query private var folders: [Folder]
    @Environment(CallLifecycle.self) private var lifecycle
    /// "+ Nuova cartella" is a text field.
    @State private var isCreating = false
    /// The folder being renamed in place.
    @State private var renaming: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow("Cartelle")
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            ForEach(FolderName.sorted(folders)) { folder in
                if renaming == folder.id {
                    SidebarNameField(initial: folder.name) { typed in
                        // `user.RENAME_FOLDER`: a name that is not valid leaves the one it has.
                        lifecycle.renameFolder(folder, to: typed)
                        renaming = nil
                    } cancel: {
                        renaming = nil
                    }
                } else {
                    SidebarItem(
                        verbatim: folder.name,
                        isSelected: model.page != .settings && model.libraryView == .folder(folder.id)
                    ) {
                        // `user.SHOW_FOLDER`.
                        model.showFolder(folder.id)
                    }
                    .contextMenu {
                        Button("Rinomina") { renaming = folder.id }
                        Button("Elimina", role: .destructive) {
                            // `user.DELETE_FOLDER`: the calls stay, without folder; if it is the
                            // folder shown, the library goes back to all calls.
                            let id = folder.id
                            lifecycle.deleteFolder(folder)
                            model.folderDeleted(id)
                        }
                    }
                }
            }
            if isCreating {
                SidebarNameField(initial: "") { typed in
                    // `user.CREATE_FOLDER`: a name that is not valid creates nothing.
                    lifecycle.createFolder(named: typed)
                    isCreating = false
                } cancel: {
                    isCreating = false
                }
            } else {
                Button {
                    isCreating = true
                } label: {
                    Text("+ Nuova cartella")
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.larpPlain)
            }
        }
    }
}

/// The text field of the sidebar, on the dark background: it takes the focus when it appears, Return
/// hands the name typed over and Esc or leaving the field cancels.
private struct SidebarNameField: View {
    let initial: String
    let commit: (String) -> Void
    let cancel: () -> Void
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(initial: String, commit: @escaping (String) -> Void, cancel: @escaping () -> Void) {
        self.initial = initial
        self.commit = commit
        self.cancel = cancel
        _text = State(initialValue: initial)
    }

    var body: some View {
        TextField(text: $text, prompt: Text("Nome della cartella").foregroundStyle(LARPColor.textMuted)) { EmptyView() }
            .textFieldStyle(.plain)
            .font(LARPFont.inter(13))
            .foregroundStyle(LARPColor.textOnDark)
            .focused($isFocused)
            .onSubmit { commit(text) }
            .onExitCommand(perform: cancel)
            .onChange(of: text) { _, new in
                // At most 60 characters can be typed.
                if new.count > FolderName.maxLength { text = String(new.prefix(FolderName.maxLength)) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { cancel() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(LARPColor.darkRaised, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(LARPColor.darkBorder, lineWidth: 1) }
            .onAppear { isFocused = true }
    }
}
