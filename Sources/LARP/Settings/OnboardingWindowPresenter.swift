import AppKit
import SwiftUI

/// The welcome window: about 960 × 680 px, not resizable, without a title bar (the buttons of
/// the window sit on the ink panel). `LSUIElement` apps are not active by default, so the app is
/// brought to the front before the window opens.
@MainActor
final class OnboardingWindowPresenter: NSObject, OnboardingWindowPresenting, NSWindowDelegate {
    var onUserClose: (@MainActor () -> Void)?
    private var window: NSWindow?

    func show(for onboarding: OnboardingController) {
        let window = window ?? makeWindow(for: onboarding)
        self.window = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        let window = window
        self.window = nil
        window?.delegate = nil
        window?.close()
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
        onUserClose?()
    }

    // MARK: Window

    private func makeWindow(for onboarding: OnboardingController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingView.windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(hex: LARPColor.Hex.paper)
        window.contentView = NSHostingView(rootView: OnboardingView(onboarding: onboarding))
        window.delegate = self
        return window
    }
}
