import AppKit
import Observation
import SwiftUI

/// What shows a recording while it runs. Replaced in tests.
@MainActor
protocol RecordingViewPresenting: AnyObject {
    /// `recorder.RECORDING_STARTED`: Hidden → Shown, on the pill.
    func recordingStarted()
    /// `recorder.RECORDING_STOPPED`: Shown → Hidden; the pill or the live window disappears.
    func recordingStopped()
    /// `user.OPEN_LIVE_WINDOW`: Pill → Live window.
    func openLiveWindow()
}

/// The two surfaces of a recording, drawn by AppKit. Replaced in tests.
@MainActor
protocol RecordingSurfaces: AnyObject {
    func showPill()
    func hidePill()
    /// Opens the live window in front of the other windows.
    func showLiveWindow()
    func hideLiveWindow()
    /// Called when the user closes the live window.
    var onLiveWindowClosed: (@MainActor () -> Void)? { get set }
}

/// The `recording-view` machine: exactly one of the pill and the live window is shown during a
/// recording, and neither outside one. The pill opens the live window; closing the window
/// brings the pill back.
///
/// It also does what the buttons of both surfaces do, so that they stay thin.
@MainActor
@Observable
final class RecordingViewController: RecordingViewPresenting {
    enum Phase: Equatable {
        /// **Hidden**: no recording is going on.
        case hidden
        /// **Shown** / **Pill**.
        case pill
        /// **Shown** / **Live window**.
        case liveWindow
    }

    /// The controller shared by the app: the recorder, the pill and the live window use it.
    static let shared = RecordingViewController()

    private(set) var phase = Phase.hidden
    /// The levels, the waveform and the recognised text shown by both surfaces.
    @ObservationIgnored let state: LiveRecordingState

    @ObservationIgnored private let surfaces: any RecordingSurfaces
    @ObservationIgnored private weak var recorder: Recorder?
    @ObservationIgnored private weak var lifecycle: CallLifecycle?

    init(
        state: LiveRecordingState = LiveRecordingState(),
        surfaces: any RecordingSurfaces = AppKitRecordingSurfaces()
    ) {
        self.state = state
        self.surfaces = surfaces
        surfaces.onLiveWindowClosed = { [weak self] in self?.liveWindowClosed() }
    }

    /// Connects what the buttons of the surfaces act on. Called once, when the app starts.
    func connect(recorder: Recorder, lifecycle: CallLifecycle) {
        self.recorder = recorder
        self.lifecycle = lifecycle
    }

    // MARK: Machine

    func recordingStarted() {
        guard phase == .hidden else { return }
        phase = .pill
        surfaces.showPill()
    }

    func recordingStopped() {
        switch phase {
        case .hidden: break
        case .pill: surfaces.hidePill()
        case .liveWindow: surfaces.hideLiveWindow()
        }
        phase = .hidden
    }

    func openLiveWindow() {
        guard phase == .pill else { return }
        surfaces.hidePill()
        phase = .liveWindow
        surfaces.showLiveWindow()
    }

    /// `user.CLOSE_LIVE_WINDOW`: the live window closes and the pill comes back.
    func closeLiveWindow() {
        guard phase == .liveWindow else { return }
        phase = .pill
        surfaces.hideLiveWindow()
        surfaces.showPill()
    }

    /// The user closed the window with its own button: the window is already gone.
    private func liveWindowClosed() {
        guard phase == .liveWindow else { return }
        phase = .pill
        surfaces.showPill()
    }

    // MARK: What the buttons do

    /// "Segnalibro": `user.ADD_BOOKMARK` on the call being recorded, at the elapsed time.
    func addBookmark() {
        guard let recorder, recorder.isRecording else { return }
        lifecycle?.addBookmarkToActiveRecording(atSeconds: TimeInterval(recorder.elapsedSeconds))
    }

    /// "Scrivi una nota…": `user.ADD_NOTE` on the call being recorded, at the elapsed time.
    func addNote(_ text: String) {
        guard let recorder, recorder.isRecording else { return }
        lifecycle?.addNoteToActiveRecording(text, atSeconds: TimeInterval(recorder.elapsedSeconds))
    }

    /// "Pausa" / "Riprendi".
    func togglePause() {
        recorder?.togglePause()
    }

    /// "Ferma": `user.STOP_RECORDING`.
    func stopRecording() {
        recorder?.stopRecording()
    }
}

// MARK: - AppKit

/// The pill and the live window as AppKit panels and windows.
@MainActor
final class AppKitRecordingSurfaces: RecordingSurfaces {
    /// The pill: 390 × 64 px, 24 px above the bottom edge of the screen of the menu bar.
    static let pillSize = NSSize(width: 390, height: 64)
    static let pillBottomGap: CGFloat = 24
    /// The live window: about 1040 × 680 px.
    static let liveWindowSize = NSSize(width: 1040, height: 680)

    var onLiveWindowClosed: (@MainActor () -> Void)?

    private var pill: NSPanel?
    private var liveWindow: NSWindow?
    private var windowObserver: (any NSObjectProtocol)?

    /// The pill centred on `visibleFrame`, 24 px above its bottom edge.
    static func pillOrigin(in visibleFrame: NSRect) -> NSPoint {
        NSPoint(x: visibleFrame.midX - pillSize.width / 2, y: visibleFrame.minY + pillBottomGap)
    }

    func showPill() {
        hidePill()
        let panel = PillPanel(
            contentRect: NSRect(origin: .zero, size: Self.pillSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let content = RecordingPillView(controller: RecordingViewController.shared, recorder: Recorder.shared)
            .larpEnvironment()
        panel.contentView = NSHostingView(rootView: content)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The first screen is the one with the menu bar.
        let visible = NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrameOrigin(Self.pillOrigin(in: visible))
        panel.orderFrontRegardless()
        pill = panel
    }

    func hidePill() {
        pill?.orderOut(nil)
        pill = nil
    }

    func showLiveWindow() {
        hideLiveWindow()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.liveWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let content = LiveWindowView(controller: RecordingViewController.shared, recorder: Recorder.shared)
            .larpEnvironment()
        window.contentView = NSHostingView(rootView: content)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "LARP"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(hex: LARPColor.Hex.ink)
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.center()
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowWillClose() }
        }
        liveWindow = window
        // `LSUIElement` apps are not active by default: the window comes to the front without a Dock icon.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func hideLiveWindow() {
        removeObserver()
        liveWindow?.close()
        liveWindow = nil
    }

    private func windowWillClose() {
        removeObserver()
        liveWindow = nil
        onLiveWindowClosed?()
    }

    private func removeObserver() {
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
        windowObserver = nil
    }
}

/// A panel that never takes the focus: a click on its buttons does not bring the app to the front.
private final class PillPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
