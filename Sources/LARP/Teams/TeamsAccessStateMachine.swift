import Foundation

/// States of the `teams-access` machine (Model `meeting-info/teams-access`).
enum TeamsAccessState: Sendable, Equatable {
    /// LARP does not read Teams.
    case notAllowed
    /// LARP waits for the user to allow it in System Settings.
    case awaitingPermission
    /// LARP reads Teams while Teams is running.
    case allowed
}

/// Events the `teams-access` machine reacts to. Events with a guard carry the facts the guard
/// needs.
enum TeamsAccessEvent: Sendable, Equatable {
    /// `macos.APP_LAUNCHED`. `permissionGranted`: macOS gives LARP the Accessibility permission.
    case appLaunched(permissionGranted: Bool)
    /// `user.OPEN_SETTINGS`.
    case openSettings(permissionGranted: Bool)
    /// `user.ALLOW_TEAMS_ACCESS`.
    case allowTeamsAccess
    /// `time.ACCESSIBILITY_CHECK_DUE`. `twoMinutesPassed`: two minutes have passed since the
    /// request.
    case accessibilityCheckDue(permissionGranted: Bool, twoMinutesPassed: Bool)
}

/// Where a `teams-access` event leads, and what it emits on the way.
struct TeamsAccessTransition: Sendable, Equatable {
    let state: TeamsAccessState
    /// `teams-access.ACCESS_LOST` is emitted.
    var emitsAccessLost = false
}

/// The transition table of the `teams-access` machine. Pure: it only says where an event leads;
/// `TeamsAccessController` performs the effects. A state that does not react to an event has no
/// entry (`nil`).
enum TeamsAccessStateMachine {
    /// How long LARP waits for the permission after "Consenti": `time.ACCESSIBILITY_CHECK_DUE`
    /// gives up once this has passed.
    static let waitLimit: TimeInterval = 120
    /// How often the permission is read while LARP waits for it.
    static let checkInterval: TimeInterval = 2

    static func target(from state: TeamsAccessState, on event: TeamsAccessEvent) -> TeamsAccessTransition? {
        switch (state, event) {
        // Not allowed
        case (.notAllowed, .appLaunched(let granted)), (.notAllowed, .openSettings(let granted)):
            return granted ? TeamsAccessTransition(state: .allowed) : nil
        case (.notAllowed, .allowTeamsAccess):
            return TeamsAccessTransition(state: .awaitingPermission)

        // Awaiting permission
        case (.awaitingPermission, .accessibilityCheckDue(let granted, let twoMinutesPassed)):
            if granted { return TeamsAccessTransition(state: .allowed) }
            return TeamsAccessTransition(state: twoMinutesPassed ? .notAllowed : .awaitingPermission)
        case (.awaitingPermission, .openSettings(let granted)):
            return granted ? TeamsAccessTransition(state: .allowed) : nil

        // Allowed
        case (.allowed, .appLaunched(let granted)), (.allowed, .openSettings(let granted)):
            return granted ? nil : TeamsAccessTransition(state: .notAllowed, emitsAccessLost: true)

        default:
            return nil
        }
    }
}
