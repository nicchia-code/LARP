import AppKit
import ApplicationServices

/// The reading of the new Microsoft Teams through the Accessibility API, kept light so that Teams
/// is never slowed down: an `AXObserver` for the windows Teams opens and the titles it changes
/// (nothing else) on the main run loop, and a timer-like wait as the base of correctness;
/// notifications only make a reading come sooner (`TeamsReadPacing`). The walks run off the main
/// actor (`TeamsTreeReader`), one at a time, and their results come back to it. Teams launching and
/// quitting are followed through the workspace notifications of AppKit.
///
/// It exists only while the reading is needed (`TeamsMeetingController`): `stop()` abandons the
/// walk in progress, and so do the quit of Teams and a new launch of it.
@MainActor
final class AccessibilityTeamsReader: TeamsReading {
    private var onReadout: (@MainActor (TeamsReadout) -> Void)?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var observer: AXObserver?
    /// The readings of the Teams process that runs; `nil` while Teams does not run.
    private var session: TeamsTreeReader<AccessibilityTeamsTreeSource>?
    private var pacing = TeamsReadPacing()
    /// Waits for the time of the next reading, then starts it.
    private var waiting: Task<Void, Never>?
    /// The walk in progress, which goes on until it notices it was cancelled; no other starts
    /// before it ends.
    private var reading: Task<Void, Never>?
    private var readingIdentifier = 0
    /// Tells a walk begun before `stop()`, a quit or a new launch that its result is not wanted.
    private var generation = 0

    func start(onReadout: @escaping @MainActor (TeamsReadout) -> Void) {
        stop()
        self.onReadout = onReadout
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == TeamsInterface.bundleIdentifier, let pid = app?.processIdentifier
                else { return }
                MainActor.assumeIsolated { self?.teamsLaunched(pid) }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == TeamsInterface.bundleIdentifier else { return }
                MainActor.assumeIsolated { self?.teamsQuit() }
            },
        ]
        if let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: TeamsInterface.bundleIdentifier
        ).first(where: { !$0.isTerminated }) {
            attach(to: running.processIdentifier)
        } else {
            onReadout(.noMeeting)
        }
    }

    func stop() {
        onReadout = nil
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens { center.removeObserver(token) }
        workspaceTokens = []
        detach()
    }

    // MARK: Teams running

    private func teamsLaunched(_ pid: pid_t) {
        guard onReadout != nil else { return }
        attach(to: pid)
    }

    private func teamsQuit() {
        guard let onReadout else { return }
        detach()
        onReadout(.noMeeting)
    }

    /// Starts reading the Teams process `pid`: a new one, with nothing remembered of an earlier
    /// launch.
    private func attach(to pid: pid_t) {
        detach()
        session = TeamsTreeReader(source: AccessibilityTeamsTreeSource(processIdentifier: pid))
        pacing = TeamsReadPacing()
        listen(to: pid)
        scheduleNextReading()
    }

    /// Abandons the walk in progress, drops what is remembered of the Teams that ran and stops
    /// listening to it.
    private func detach() {
        generation += 1
        waiting?.cancel()
        waiting = nil
        reading?.cancel()
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        session = nil
    }

    /// Listens to the two things Teams announces that make a reading come sooner: a window opened and
    /// a title changed.
    private func listen(to pid: pid_t) {
        let callback: AXObserverCallback = { _, _, notification, context in
            guard let context else { return }
            let reader = Unmanaged<AccessibilityTeamsReader>.fromOpaque(context).takeUnretainedValue()
            let opened = (notification as String) == kAXWindowCreatedNotification
            MainActor.assumeIsolated { reader.announced(windowOpened: opened) }
        }
        var created: AXObserver?
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXTitleChangedNotification] {
            _ = AXObserverAddNotification(created, app, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
    }

    // MARK: Reading

    /// Teams announced a change: the next reading may come sooner.
    private func announced(windowOpened: Bool) {
        guard onReadout != nil, session != nil else { return }
        if windowOpened {
            pacing.windowOpened(at: .now)
        } else {
            pacing.announced(at: .now)
        }
        scheduleNextReading()
    }

    /// Waits for the time the pacing gives, then reads. Nothing is scheduled while a walk is still
    /// running (its end schedules the next) or when this launch of Teams was given up.
    private func scheduleNextReading() {
        waiting?.cancel()
        waiting = nil
        guard onReadout != nil, let session, !session.hasGivenUp, reading == nil else { return }
        let start = pacing.nextStart(now: .now)
        waiting = Task { [weak self] in
            try? await Task.sleep(until: start, clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.beginReading()
        }
    }

    /// Walks Teams off the main actor and hands the result back to it.
    private func beginReading() {
        waiting = nil
        guard reading == nil, let session else { return }
        pacing.readStarted()
        readingIdentifier += 1
        let identifier = readingIdentifier
        let current = generation
        reading = Task.detached(priority: .utility) { [weak self] in
            let result = session.read(isCancelled: { Task.isCancelled })
            await self?.readingEnded(result, identifier: identifier, generation: current)
        }
    }

    private func readingEnded(_ result: TeamsTreeResult, identifier: Int, generation current: Int) {
        guard identifier == readingIdentifier else { return }
        reading = nil
        // A walk abandoned by `stop()`, a quit or a new launch gives nothing back.
        guard current == generation, let onReadout, result.outcome != .cancelled else {
            scheduleNextReading()
            return
        }
        pacing.readFinished(at: .now, pause: result.pause)
        TeamsLog.reading(result)
        if result.gaveUp { TeamsLog.gaveUp() }
        if let readout = result.readout { onReadout(readout) }
        scheduleNextReading()
    }
}
