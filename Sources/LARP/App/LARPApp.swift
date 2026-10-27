import SwiftData
import SwiftUI

/// Menu bar app (no Dock icon, see `LSUIElement` in Info.plist) with an archive
/// window and a settings scene.
@main
struct LARPApp: App {
    /// Identifier of the archive window, used with `openWindow(id:)`.
    static let archiveWindowID = "archive"

    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ArchiveStore.makeContainer()
        } catch {
            fatalError("Impossibile aprire l'archivio: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra("LARP", systemImage: "mic") {
            MenuBarContent()
        }

        Window("Archivio", id: Self.archiveWindowID) {
            ArchiveView()
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
