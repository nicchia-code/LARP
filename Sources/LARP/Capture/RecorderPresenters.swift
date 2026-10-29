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

/// Shows and hides the warning that the sound of the others cannot be removed from
/// the microphone. Replaced in tests.
@MainActor
protocol EchoCancellationWarningPresenting: AnyObject {
    /// Shows the warning; it goes away by itself after `EchoCancellationWarningPanelController.duration`.
    /// Showing it again restarts the countdown.
    func show()
    func hide()
}

/// Shows and hides the notice that a recording started by hand records only the
/// microphone. Replaced in tests.
@MainActor
protocol SystemAudioUnavailablePresenting: AnyObject {
    /// Shows the notice; it goes away by itself after `SystemAudioUnavailablePanelController.duration`.
    /// `permissionMissing` adds a button opening the system audio pane of System Settings.
    func show(permissionMissing: Bool)
    func hide()
}

/// Shows and hides the notice that the microphone is lost. Replaced in tests.
@MainActor
protocol MicrophoneLostPresenting: AnyObject {
    /// Shows the notice; it stays until `hide()`.
    func show()
    func hide()
}

/// Shows and hides the notice that the system audio is lost. Replaced in tests.
@MainActor
protocol SystemAudioLostPresenting: AnyObject {
    /// Shows the notice; it stays until `hide()`.
    func show()
    func hide()
}

/// The proposal: a small panel under the menu bar icon that never takes the focus.
@MainActor
final class ProposalPanelController: ProposalPresenting {
    private var panel: NSPanel?

    func show(appName: String, accept: @escaping @MainActor () -> Void) {
        hide()
        panel = MenuBarPanel.show(ProposalView(appName: appName, accept: accept))
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// The warning about the echo: a small panel under the menu bar icon that never
/// takes the focus and disappears by itself.
@MainActor
final class EchoCancellationWarningPanelController: EchoCancellationWarningPresenting {
    /// How long the warning stays on screen.
    static let duration: Duration = .seconds(10)
    static let message = "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte."

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show() {
        hide()
        panel = MenuBarPanel.show(EchoCancellationWarningView(message: Self.message))
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

/// The notice that only the microphone is recorded: a small panel under the menu bar
/// icon that never takes the focus and disappears by itself.
@MainActor
final class SystemAudioUnavailablePanelController: SystemAudioUnavailablePresenting {
    /// How long the notice stays on screen.
    static let duration: Duration = .seconds(10)
    static let message = "Audio di sistema non disponibile: si registra solo il microfono."

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(permissionMissing: Bool) {
        hide()
        var openSettings: (@MainActor () -> Void)?
        if permissionMissing {
            openSettings = { NSWorkspace.shared.open(RecordingPermission.systemAudio.settingsURL) }
        }
        panel = MenuBarPanel.show(
            NoticeView(symbol: "speaker.slash", message: Self.message, buttonTitle: "Apri Impostazioni di Sistema", action: openSettings))
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

/// The notice that the microphone is lost: a small panel under the menu bar icon that
/// never takes the focus and stays until it is hidden.
@MainActor
final class MicrophoneLostPanelController: MicrophoneLostPresenting {
    static let message = "Microfono non disponibile: la registrazione prosegue senza la tua voce."

    private var panel: NSPanel?

    func show() {
        hide()
        panel = MenuBarPanel.show(NoticeView(symbol: "mic.slash", message: Self.message), stacked: true)
    }

    func hide() {
        guard let panel else { return }
        MenuBarPanel.close(panel)
        self.panel = nil
    }
}

/// The notice that the system audio is lost: a small panel under the menu bar icon that
/// never takes the focus and stays until it is hidden. Stacked with the one of the
/// microphone when both are lost.
@MainActor
final class SystemAudioLostPanelController: SystemAudioLostPresenting {
    static let message = "Audio di sistema non disponibile: la registrazione prosegue senza gli altri partecipanti."

    private var panel: NSPanel?

    func show() {
        hide()
        panel = MenuBarPanel.show(NoticeView(symbol: "speaker.slash", message: Self.message), stacked: true)
    }

    func hide() {
        guard let panel else { return }
        MenuBarPanel.close(panel)
        self.panel = nil
    }
}

/// Panels under the menu bar icon that never take the focus.
@MainActor
private enum MenuBarPanel {
    /// The panels that stay until they are hidden, from the top: each one sits under the
    /// previous one and moves up when one above it goes away.
    private static var stack: [NSPanel] = []

    /// With `stacked` the panel goes under the stacked panels that are already shown.
    static func show<Content: View>(_ content: Content, stacked: Bool = false) -> NSPanel {
        let hosting = NSHostingView(rootView: content)
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
        if stacked { stack.append(panel) }
        layoutStack()
        panel.orderFrontRegardless()
        return panel
    }

    /// Hides a panel and closes the gap it leaves in the stack.
    static func close(_ panel: NSPanel) {
        panel.orderOut(nil)
        stack.removeAll { $0 === panel }
        layoutStack()
    }

    private static func layoutStack() {
        var top: CGFloat?
        for panel in stack {
            let size = panel.frame.size
            let point = origin(for: size, below: top)
            panel.setFrameOrigin(point)
            top = point.y
        }
    }

    /// Centered under the menu bar icon (the status bar window of this app), or at
    /// the top right of the main screen if the icon cannot be found.
    private static func origin(for size: NSSize, below top: CGFloat? = nil) -> NSPoint {
        let gap: CGFloat = 6
        let statusFrame = NSApp.windows.first { $0.className.contains("StatusBar") }?.frame
        let screen = NSScreen.screens.first { screen in
            statusFrame.map { screen.frame.contains(NSPoint(x: $0.midX, y: $0.midY)) } ?? false
        } ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preferredX = statusFrame.map { $0.midX - size.width / 2 } ?? visible.maxX - size.width - 12
        let x = min(max(preferredX, visible.minX + 8), visible.maxX - size.width - 8)
        let top = top ?? statusFrame.map { $0.minY } ?? visible.maxY
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

private struct EchoCancellationWarningView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "headphones")
                .foregroundStyle(.secondary)
            Text(message)
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }
}

/// A notice with an icon, a text and optionally a button.
private struct NoticeView: View {
    let symbol: String
    let message: String
    var buttonTitle: String?
    var action: (@MainActor () -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(message)
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }
}
