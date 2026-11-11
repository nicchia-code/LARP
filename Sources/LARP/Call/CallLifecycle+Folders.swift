import Foundation
import SwiftData

/// The rules for the name of a folder.
enum FolderName {
    /// A name is at most this many characters long.
    static let maxLength = 60

    /// `typed` trimmed; `nil` when it is empty once trimmed or longer than `maxLength` characters.
    static func cleaned(_ typed: String) -> String? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= maxLength else { return nil }
        return name
    }

    /// Whether `a` and `b` are the same name ignoring case, accents and character width.
    static func same(_ a: String, _ b: String) -> Bool {
        CallSearch.normalized(a) == CallSearch.normalized(b)
    }

    /// The folders in alphabetical order, ignoring case and accents.
    static func sorted(_ folders: [Folder]) -> [Folder] {
        folders.sorted { lhs, rhs in
            let order = lhs.name.compare(
                rhs.name, options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: .current)
            return order == .orderedSame ? lhs.name < rhs.name : order == .orderedAscending
        }
    }
}

/// The `folder` machine (Model `library/folder`): folders the user made to group calls. A call is in
/// at most one folder, which does not own it, and stays in "Tutte le call" whatever its folder.
extension CallLifecycle {
    /// The folders of the archive in alphabetical order.
    func folders() -> [Folder] {
        FolderName.sorted((try? context.fetch(FetchDescriptor<Folder>())) ?? [])
    }

    /// `user.CREATE_FOLDER`: a folder with the name typed, trimmed, when it is not empty, at most 60
    /// characters long and no other folder has it ignoring case and accents; otherwise nothing is
    /// created and the answer is `nil`.
    @discardableResult
    func createFolder(named typed: String) -> Folder? {
        guard let name = FolderName.cleaned(typed), !isTaken(name, excluding: nil) else { return nil }
        let folder = Folder(name: name)
        context.insert(folder)
        save()
        return folder
    }

    /// `user.RENAME_FOLDER`: the new name, trimmed, replaces the name when it follows the same rules
    /// as a new folder's; otherwise the folder keeps its name. Writing the name it has again, with
    /// other case, is a rename. Answers whether the name changed.
    @discardableResult
    func renameFolder(_ folder: Folder, to typed: String) -> Bool {
        guard let name = FolderName.cleaned(typed), name != folder.name,
            !isTaken(name, excluding: folder)
        else { return false }
        folder.name = name
        save()
        return true
    }

    /// `user.DELETE_FOLDER`: the folder disappears; its calls stay in the archive without folder.
    func deleteFolder(_ folder: Folder) {
        for call in folder.calls {
            call.folder = nil
        }
        context.delete(folder)
        save()
    }

    /// `user.MOVE_TO_FOLDER`: the call leaves its previous folder, if any, and joins `folder`;
    /// `nil` ("Nessuna cartella") takes it out of its folder.
    func moveCall(_ call: Call, to folder: Folder?) {
        guard call.folder?.id != folder?.id else { return }
        call.folder = folder
        save()
    }

    private func isTaken(_ name: String, excluding other: Folder?) -> Bool {
        folders().contains { $0.id != other?.id && FolderName.same($0.name, name) }
    }
}
