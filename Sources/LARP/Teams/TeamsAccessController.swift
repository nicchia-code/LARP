import Foundation
import Observation

/// The `teams-access` machine: whether LARP may read Microsoft Teams, that is whether macOS gives
/// it the Accessibility permission.
///
/// macOS does not tell when the permission is granted or taken away, so it is read again at
/// launch, when the settings open and, after "Consenti", every two seconds for two minutes. The
/// state of the permission lives in memory only; what is kept in `UserDefaults` is that it was
/// seen granted at least once, so that its loss after a new version of the app (ad-hoc signed
/// builds lose it at every version) can be recognised.
@MainActor
@Observable
final class TeamsAccessController {
    /// The controller shared by the app: the settings page, the welcome window and the reading of
    /// Teams use the same instance.
    static let shared = TeamsAccessController()

    private(set) var state: TeamsAccessState = .notAllowed

    /// LARP reads Teams while it runs.
    var isAllowed: Bool { state == .allowed }

    /// The permission was granted to an earlier version and is missing now: the popover and the
    /// settings say that it must be allowed again.
    var mustBeAllowedAgain: Bool {
        state == .notAllowed && defaults.bool(forKey: SettingsKey.teamsAccessGranted)
    }

    @ObservationIgnored private let permission: any AccessibilityPermission
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let checkInterval: Duration
    @ObservationIgnored private var requestedAt: Date?
    @ObservationIgnored private var checks: Task<Void, Never>?
    /// `teams-access.ACCESS_LOST`, for the `teams-meeting` machine.
    @ObservationIgnored private let accessLost = EventBroadcaster<Void>()
    /// Every change of whether Teams is allowed, for the reading of Teams.
    @ObservationIgnored private let allowedChanged = EventBroadcaster<Bool>()

    init(
        permission: any AccessibilityPermission = SystemAccessibilityPermission(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        checkInterval: Duration = .seconds(TeamsAccessStateMachine.checkInterval)
    ) {
        self.permission = permission
        self.defaults = defaults
        self.now = now
        self.checkInterval = checkInterval
    }

    // MARK: Events

    /// `macos.APP_LAUNCHED`. Call once, at launch.
    func appLaunched() {
        apply(.appLaunched(permissionGranted: permission.isGranted))
    }

    /// `user.OPEN_SETTINGS`.
    func openSettings() {
        apply(.openSettings(permissionGranted: permission.isGranted))
    }

    /// `user.ALLOW_TEAMS_ACCESS`: from Not allowed, macOS asks the user to allow LARP and System
    /// Settings opens on the Accessibility pane; the permission is then awaited.
    func allowTeamsAccess() {
        let before = state
        apply(.allowTeamsAccess)
        if before == .notAllowed, state == .awaitingPermission {
            requestedAt = now()
            permission.request()
            startChecking()
        }
    }

    /// `time.ACCESSIBILITY_CHECK_DUE`: the permission is read again while it is awaited.
    func accessibilityCheckDue() {
        let passed = requestedAt.map { now().timeIntervalSince($0) >= TeamsAccessStateMachine.waitLimit } ?? true
        apply(.accessibilityCheckDue(permissionGranted: permission.isGranted, twoMinutesPassed: passed))
    }

    // MARK: News

    /// A new stream that yields `teams-access.ACCESS_LOST` every time the permission goes missing
    /// while Teams was allowed.
    var accessLostEvents: AsyncStream<Void> {
        accessLost.stream()
    }

    /// A new stream that yields whether Teams is allowed every time that changes.
    var allowedChanges: AsyncStream<Bool> {
        allowedChanged.stream()
    }

    // MARK: Machine

    private func apply(_ event: TeamsAccessEvent) {
        guard let transition = TeamsAccessStateMachine.target(from: state, on: event) else { return }
        let before = state
        state = transition.state
        if state != .awaitingPermission {
            stopChecking()
        }
        if state == .allowed {
            defaults.set(true, forKey: SettingsKey.teamsAccessGranted)
        }
        if before != state {
            if before == .allowed || state == .allowed {
                allowedChanged.emit(state == .allowed)
            }
        }
        if transition.emitsAccessLost {
            accessLost.emit(())
        }
    }

    /// Reads the permission every two seconds while it is awaited.
    private func startChecking() {
        checks?.cancel()
        let interval = checkInterval
        checks = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.accessibilityCheckDue()
            }
        }
    }

    private func stopChecking() {
        checks?.cancel()
        checks = nil
        requestedAt = nil
    }
}
