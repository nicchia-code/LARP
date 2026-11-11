import AppKit
import ApplicationServices

/// What LARP knows of the interface of the new Microsoft Teams. Web elements are matched by their
/// `AXDOMIdentifier`, never by their titles or descriptions, which change with the language.
///
/// `call-duration-custom` is measured; the identifiers of the participant list and of the mark on
/// whoever speaks are LARP's best reading of the Teams interface, which changes with every version
/// of Teams: when they are not there the people and the speaker are simply not read (an
/// experimental reading).
enum TeamsInterface {
    /// The main process of the new Teams; the classic Teams (`com.microsoft.teams`) is not read.
    static let bundleIdentifier = "com.microsoft.teams2"
    /// The element that is in a window while Teams is in a meeting.
    static let meetingMarker = "call-duration-custom"
    /// An item of the list of participants.
    static let participantItemPrefix = "roster-participant"
    /// The mark Teams puts on whoever speaks.
    static let speakingMarkerPrefix = "active-speaker"
    /// How many nodes of the interface of Teams one reading visits at most.
    static let nodeLimit = 25_000
    /// How many seconds a call into Teams may take.
    static let messagingTimeout: Float = 2
}

/// One reading of the interface of Teams through the Accessibility API. It blocks while it walks
/// the tree, so it runs off the main actor.
enum TeamsTreeReader {
    private struct Walk {
        var budget: Int
        var sawIdentifier = false
        var hasMarker = false
        var people: [String] = []
        var speaker: String?
    }

    private static let attributeNames: [String] = [
        "AXDOMIdentifier", kAXChildrenAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute,
    ]

    /// Reads the meeting the Teams process `processIdentifier` shows. When nothing of its web
    /// content is exposed, Teams is asked to expose it to assistive apps and read again.
    static func read(processIdentifier: pid_t) -> TeamsReadout {
        let app = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(app, TeamsInterface.messagingTimeout)
        var result = scan(app)
        if !result.sawIdentifier {
            // Chromium builds the tree of its web content only for an assistive client. Both
            // calls answer with an error but are the signal that makes it do so.
            _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            result = scan(app)
        }
        return TeamsReadout(meeting: result.meeting)
    }

    private static func scan(_ app: AXUIElement) -> (sawIdentifier: Bool, meeting: TeamsReadout.Meeting?) {
        var budget = TeamsInterface.nodeLimit
        var sawIdentifier = false
        for window in elements(of: app, attribute: kAXWindowsAttribute) {
            var walk = Walk(budget: budget)
            visit(window, itemName: nil, walk: &walk)
            budget = walk.budget
            sawIdentifier = sawIdentifier || walk.sawIdentifier
            // Early exit at the first window that holds the marker.
            if walk.hasMarker {
                let title = TeamsText.meetingTitle(
                    fromWindowTitle: attributes(of: window, [kAXTitleAttribute]).first.flatMap { $0 as? String })
                let speaker = TeamsText.personName(from: walk.speaker)
                return (
                    true,
                    TeamsReadout.Meeting(
                        title: title, people: TeamsText.people(from: walk.people), speaker: speaker)
                )
            }
            if budget <= 0 { break }
        }
        return (sawIdentifier, nil)
    }

    /// Visits `element` and its descendants while the budget lasts. `itemName` is the label of the
    /// nearest item above that has one, the person a speaking mark belongs to.
    private static func visit(_ element: AXUIElement, itemName: String?, walk: inout Walk) {
        guard walk.budget > 0 else { return }
        walk.budget -= 1
        let values = attributes(of: element, attributeNames)
        let identifier = values[0] as? String
        let label = nonEmpty(values[2] as? String) ?? nonEmpty(values[3] as? String)
        var name = itemName
        if let identifier, !identifier.isEmpty {
            walk.sawIdentifier = true
            if identifier == TeamsInterface.meetingMarker {
                walk.hasMarker = true
            }
            if identifier.hasPrefix(TeamsInterface.participantItemPrefix) {
                name = label ?? firstText(in: values[1]) ?? itemName
                if let name { walk.people.append(name) }
            }
            if identifier.hasPrefix(TeamsInterface.speakingMarkerPrefix), walk.speaker == nil {
                walk.speaker = name ?? label
            }
        } else if let label {
            name = label
        }
        for child in elementList(values[1]) {
            visit(child, itemName: name, walk: &walk)
        }
    }

    /// The first text among the direct children of an item.
    private static func firstText(in children: Any?) -> String? {
        for child in elementList(children) {
            let values = attributes(of: child, [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute])
            if let text = values.lazy.compactMap({ nonEmpty($0 as? String) }).first { return text }
        }
        return nil
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// The values of `names` for `element`, in order; `nil` for one that is missing or failed.
    private static func attributes(of element: AXUIElement, _ names: [String]) -> [Any?] {
        var copied: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &copied)
        guard error == .success, let items = copied as? [AnyObject] else {
            return Array(repeating: nil, count: names.count)
        }
        return items.map { item in
            if CFGetTypeID(item) == AXValueGetTypeID(), AXValueGetType(item as! AXValue) == .axError {
                return nil
            }
            return item
        }
    }

    private static func elements(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        elementList(attributes(of: element, [attribute]).first ?? nil)
    }

    private static func elementList(_ value: Any?) -> [AXUIElement] {
        guard let items = value as? [AnyObject] else { return [] }
        return items.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
        }
    }
}

/// The reading of the new Microsoft Teams through the Accessibility API: an `AXObserver` for
/// window, title, layout and destroyed notifications on the main run loop and a 2-second timer as
/// the base of correctness; notifications only make a reading come sooner, and at most one every
/// 250 ms. Readings run off the main actor and their results come back to it. Teams launching and
/// quitting are followed through the workspace notifications of AppKit.
@MainActor
final class AccessibilityTeamsReader: TeamsReading {
    /// How often Teams is read whatever it announces.
    static let interval: TimeInterval = 2
    /// The shortest time between two readings started by what Teams announces.
    static let announcementSpacing: Duration = .milliseconds(250)

    private var onReadout: (@MainActor (TeamsReadout) -> Void)?
    private var timer: Timer?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var processIdentifier: pid_t?
    private var observer: AXObserver?
    private var readingInFlight = false
    private var readAgainWhenDone = false
    private var lastReadStart: ContinuousClock.Instant?
    private var trailingRead: Task<Void, Never>?
    /// Tells a reading begun before `stop()` that its result is not wanted.
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
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readNow() }
        }
        readNow()
    }

    func stop() {
        generation += 1
        onReadout = nil
        timer?.invalidate()
        timer = nil
        trailingRead?.cancel()
        trailingRead = nil
        readAgainWhenDone = false
        readingInFlight = false
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens { center.removeObserver(token) }
        workspaceTokens = []
        detach()
    }

    // MARK: Teams running

    private func teamsLaunched(_ pid: pid_t) {
        guard onReadout != nil else { return }
        attach(to: pid)
        readNow()
    }

    private func teamsQuit() {
        guard onReadout != nil else { return }
        detach()
        readNow()
    }

    /// Listens to what Teams announces: windows, titles, layout and destroyed elements.
    private func attach(to pid: pid_t) {
        detach()
        processIdentifier = pid
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            let reader = Unmanaged<AccessibilityTeamsReader>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { reader.announced() }
        }
        var created: AXObserver?
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [
            kAXWindowCreatedNotification, kAXTitleChangedNotification, kAXLayoutChangedNotification,
            kAXUIElementDestroyedNotification,
        ] {
            _ = AXObserverAddNotification(created, app, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        processIdentifier = nil
    }

    // MARK: Reading

    /// Teams announced a change: it is read now, unless a reading started less than 250 ms ago, in
    /// which case one reading follows when the time has passed.
    private func announced() {
        guard onReadout != nil else { return }
        if let lastReadStart {
            let elapsed = ContinuousClock.now - lastReadStart
            if elapsed < Self.announcementSpacing {
                guard trailingRead == nil else { return }
                let wait = Self.announcementSpacing - elapsed
                trailingRead = Task { [weak self] in
                    try? await Task.sleep(for: wait)
                    guard !Task.isCancelled else { return }
                    self?.trailingRead = nil
                    self?.readNow()
                }
                return
            }
        }
        readNow()
    }

    /// Reads Teams off the main actor and hands the result back to it. A reading made while another
    /// one runs follows it.
    private func readNow() {
        guard let onReadout else { return }
        guard let pid = processIdentifier else {
            onReadout(.noMeeting)
            return
        }
        guard !readingInFlight else {
            readAgainWhenDone = true
            return
        }
        readingInFlight = true
        lastReadStart = .now
        let current = generation
        Task { [weak self] in
            let readout = await Task.detached(priority: .utility) {
                TeamsTreeReader.read(processIdentifier: pid)
            }.value
            guard let self, self.generation == current else { return }
            self.readingInFlight = false
            self.onReadout?(readout)
            if self.readAgainWhenDone {
                self.readAgainWhenDone = false
                self.announced()
            }
        }
    }
}
