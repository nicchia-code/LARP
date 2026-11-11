import AppKit
import Foundation

/// Shows a folder in the Finder.
@MainActor
protocol ArchiveRevealing {
    /// Opens the Finder on the parent of `folder`, with `folder` selected.
    func reveal(_ folder: URL)
}

/// The Finder, through `NSWorkspace.activateFileViewerSelecting`.
@MainActor
struct FinderArchiveRevealer: ArchiveRevealing {
    func reveal(_ folder: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

/// Where the archive lives, as the settings show it: the folder `LARP` of Application Support, which
/// holds the store, the recordings and the models. The location is only shown, it cannot be changed.
@MainActor
final class ArchiveLocationController {
    /// The controller shared by the app: the settings page reads it.
    static let shared = ArchiveLocationController()

    /// The folder of the archive.
    let folder: URL
    private let revealer: any ArchiveRevealing

    init(folder: URL = AppPaths.applicationSupportFolder, revealer: any ArchiveRevealing = FinderArchiveRevealer()) {
        self.folder = folder
        self.revealer = revealer
    }

    /// The path of the archive shortened with "~" when it is inside the home folder.
    var displayPath: String {
        (folder.path as NSString).abbreviatingWithTildeInPath
    }

    /// `user.REVEAL_ARCHIVE`: the Finder opens with the folder of the archive selected; the page stays
    /// on the settings.
    func reveal() {
        revealer.reveal(folder)
    }
}
