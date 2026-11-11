import AppKit
import SwiftData
import SwiftUI

/// The main window of LARP, about 1200 × 920 px, at least 900 × 600, without a visible title bar or
/// toolbar: the buttons of the window sit on the dark sidebar. `LSUIElement` apps are not active by
/// default, so the app is brought to the front before the window opens.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    static let initialSize = NSSize(width: 1200, height: 920)
    static let minimumSize = NSSize(width: 900, height: 600)

    let model = MainWindowModel()
    private var container: ModelContainer?
    private var lifecycle: CallLifecycle?
    private var window: NSWindow?

    /// Gives the window what its views need; called once when the app starts.
    func configure(container: ModelContainer, lifecycle: CallLifecycle) {
        self.container = container
        self.lifecycle = lifecycle
    }

    /// `user.OPEN_WINDOW`: the app comes to the front and the window is shown on the library; a
    /// window already open stays on the page it shows.
    func openLibrary() {
        let wasOpen = window?.isVisible ?? false
        if !wasOpen { model.windowOpened() }
        bringToFront()
    }

    /// `user.OPEN_SETTINGS`: the app comes to the front and the window is shown on the settings.
    func openSettings() {
        model.showSettings()
        bringToFront()
    }

    private func bringToFront() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: NSWindowDelegate

    /// `user.CLOSE_WINDOW`.
    func windowWillClose(_ notification: Notification) {
        model.windowClosed()
    }

    // MARK: Window

    private func makeWindow() -> NSWindow {
        guard let container, let lifecycle else {
            preconditionFailure("MainWindowController.configure(container:lifecycle:) was not called")
        }
        // About 1200 × 920 px, smaller only when the screen is.
        let visible = NSScreen.main?.visibleFrame.size ?? Self.initialSize
        let size = NSSize(
            width: max(Self.minimumSize.width, min(Self.initialSize.width, visible.width)),
            height: max(Self.minimumSize.height, min(Self.initialSize.height, visible.height)))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "LARP"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.minSize = Self.minimumSize
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(hex: LARPColor.Hex.paper)
        window.contentView = NSHostingView(
            rootView: MainWindowView(model: model)
                .modelContainer(container)
                .environment(lifecycle)
                .larpEnvironment())
        window.setContentSize(size)
        window.delegate = self
        return window
    }
}
