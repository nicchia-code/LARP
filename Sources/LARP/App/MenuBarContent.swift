import AppKit
import SwiftUI

/// Content of the menu bar menu.
struct MenuBarContent: View {
    let recorder: Recorder
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if recorder.isRecording {
            Button("Ferma registrazione") {
                recorder.stopRecording()
            }
        } else {
            Button("Registra") {
                Task { await recorder.startRecording() }
            }
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
