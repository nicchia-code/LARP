import AppKit
import Observation
import SwiftUI

/// The menu bar icon and the popover it opens (`requirements/ui#recorder`).
///
/// The icon is the coloured LARP mark outside a recording; during a recording it is a red `#FF5A40`
/// dot (`#A3A69B` while paused) followed by the elapsed time, updated every second, in digits of equal
/// width. A click opens a dark popover under the icon in place of a menu; a click elsewhere closes it.
@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var recorder: Recorder?
    private var popover: PopoverPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// The frame of the menu bar icon on the screen: the panels of the recorder sit under it.
    var buttonFrame: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// Puts the icon in the menu bar; called once when the app starts.
    func start(recorder: Recorder) {
        guard statusItem == nil else { return }
        self.recorder = recorder
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.sendAction(on: [.leftMouseDown])
        item.button?.setAccessibilityLabel("LARP")
        statusItem = item
        refresh()
    }

    /// Draws the icon for the state of the recorder and draws it again whenever that changes.
    private func refresh() {
        guard let recorder, let button = statusItem?.button else { return }
        let (isRecording, isPaused, elapsed) = withObservationTracking {
            (recorder.isRecording, recorder.isPaused, recorder.elapsedSeconds)
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        if isRecording {
            let dot = isPaused ? LARPColor.Hex.textMuted : LARPColor.Hex.recording
            button.image = LarpMarkImage.dot(NSColor(hex: dot))
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(
                string: " " + Recorder.formatElapsed(elapsed),
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)])
        } else {
            button.image = LarpMarkImage.menuBarIcon()
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    // MARK: Popover

    @objc private func togglePopover() {
        if popover != nil { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        guard popover == nil else { return }
        let panel = PopoverPanel(
            content: PopoverView(close: { [weak self] in self?.closePopover() }, resize: { [weak self] in self?.position($0) }))
        popover = panel
        position(panel.fittingSize)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        // A click outside the popover, in any app, and Esc close it.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) {
            [weak self] event in
            guard let self, let popover = self.popover else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.closePopover()
                    return nil
                }
                return event
            }
            if event.window !== popover, event.window !== self.statusItem?.button?.window {
                self.closePopover()
            }
            return event
        }
    }

    private func closePopover() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        popover?.orderOut(nil)
        popover = nil
    }

    /// Puts the popover of the given size under the icon, centred on it and inside the screen.
    private func position(_ size: CGSize) {
        guard let popover else { return }
        let gap: CGFloat = 6
        let anchor = buttonFrame
        let screen = NSScreen.screens.first { screen in
            anchor.map { screen.frame.contains(NSPoint(x: $0.midX, y: $0.midY)) } ?? false
        } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preferredX = anchor.map { $0.midX - size.width / 2 } ?? visible.maxX - size.width - 12
        let x = min(max(preferredX, visible.minX + 8), visible.maxX - size.width - 8)
        let top = anchor?.minY ?? visible.maxY
        popover.setFrame(NSRect(x: x, y: top - gap - size.height, width: size.width, height: size.height), display: true)
    }
}

/// The popover: a borderless panel on ink that can take the keyboard focus (the choice of the
/// microphone is a menu), above the other windows, with a soft shadow.
private final class PopoverPanel: NSPanel {
    private let hosting: NSHostingView<AnyView>

    init<Content: View>(content: Content) {
        let hosting = NSHostingView(rootView: AnyView(content))
        self.hosting = hosting
        super.init(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = hosting
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    var fittingSize: CGSize { hosting.fittingSize }
    override var canBecomeKey: Bool { true }
}
