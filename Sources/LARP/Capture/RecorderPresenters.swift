import AppKit
import SwiftUI

/// Shows and hides the proposal to record. Replaced in tests.
@MainActor
protocol ProposalPresenting: AnyObject {
    /// Shows the proposal for the call app; `accept` runs when the user taps "Registra".
    func show(appName: String, accept: @escaping @MainActor () -> Void)
    func hide()
}

/// Tells the user that a permission is missing. Replaced in tests.
@MainActor
protocol PermissionAlertPresenting: AnyObject {
    func present(missing permission: RecordingPermission)
}

/// The alert for a missing permission, with a button opening the right pane of
/// System Settings.
@MainActor
final class PermissionAlertPresenter: PermissionAlertPresenting {
    func present(missing permission: RecordingPermission) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = permission.alertTitle
        alert.informativeText = permission.alertMessage
        alert.addButton(withTitle: "Apri Impostazioni di Sistema")
        alert.addButton(withTitle: "Annulla")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(permission.settingsURL)
        }
    }
}

/// Tells the user that a recording did not start because the capture failed.
/// Replaced in tests.
@MainActor
protocol CaptureFailureAlertPresenting: AnyObject {
    /// `reason` says why, in Italian, in a sentence the user can read.
    func present(reason: String)
}

/// The alert for a capture that did not start: the recording was not saved.
@MainActor
final class CaptureFailureAlertPresenter: CaptureFailureAlertPresenting {
    func present(reason: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Registrazione non partita"
        alert.informativeText = "LARP non è riuscito ad avviare la cattura dell'audio: la registrazione non è stata salvata.\n\n\(reason)"
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }
}

/// The proposal: a small panel under the menu bar icon that never takes the focus.
@MainActor
final class ProposalPanelController: ProposalPresenting {
    private var panel: NSPanel?

    func show(appName: String, accept: @escaping @MainActor () -> Void) {
        hide()
        let hosting = NSHostingView(rootView: ProposalView(appName: appName, accept: accept))
        let size = hosting.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameOrigin(origin(for: size))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Centered under the menu bar icon (the status bar window of this app), or at
    /// the top right of the main screen if the icon cannot be found.
    private func origin(for size: NSSize) -> NSPoint {
        let gap: CGFloat = 6
        let statusFrame = NSApp.windows.first { $0.className.contains("StatusBar") }?.frame
        let screen = NSScreen.screens.first { screen in
            statusFrame.map { screen.frame.contains(NSPoint(x: $0.midX, y: $0.midY)) } ?? false
        } ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preferredX = statusFrame.map { $0.midX - size.width / 2 } ?? visible.maxX - size.width - 12
        let x = min(max(preferredX, visible.minX + 8), visible.maxX - size.width - 8)
        let top = statusFrame.map { $0.minY } ?? visible.maxY
        return NSPoint(x: x, y: top - size.height - gap)
    }
}

private struct ProposalView: View {
    let appName: String
    let accept: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.secondary)
            Text("Call rilevata in \(appName)")
            Button("Registra", action: accept)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }
}
