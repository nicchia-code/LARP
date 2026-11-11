import Foundation
import SwiftData

/// A folder the user made to group calls. A call is in at most one folder, which does not own it:
/// deleting the folder leaves its calls in the archive without folder, and every call stays in "Tutte
/// le call" whatever its folder. A store saved before folders existed opens without folders.
@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    /// The name, trimmed and unique among the folders ignoring case and accents (see `FolderName`).
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Call.folder)
    var calls: [Call] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
