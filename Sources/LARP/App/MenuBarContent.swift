import AppKit
import SwiftUI

/// Content of the menu bar menu. Recording is not wired yet.
struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Registra") {
            // Recording logic is added by the recording Tasks.
        }

        Button("Apri archivio") {
            NSApp.activate()
            openWindow(id: LARPApp.archiveWindowID)
        }

        // `LSUIElement` apps are not active by default, so the Settings window
        // would open behind other apps without an explicit activation.
        SettingsLink {
            Text("Impostazioni…")
        }
        .keyboardShortcut(",")
        .simultaneousGesture(TapGesture().onEnded { NSApp.activate() })

        Divider()

        Button("Esci") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
