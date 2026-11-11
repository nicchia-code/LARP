import Foundation

/// The news the settings page gives to the machines of the Settings feature.
@MainActor
enum SettingsEvents {
    /// `user.OPEN_SETTINGS`: the login item is read again (`launch-at-login`), omp is looked for
    /// again, abandoning a check in progress (`assistant-status`), and what macOS grants for the
    /// calendar is read again (`calendar-access`) and the Accessibility permission is read again
    /// (`teams-access`).
    static func openSettings(
        launchAtLogin: LaunchAtLogin = .shared,
        assistantStatus: AssistantStatusController = .shared,
        calendarAccess: CalendarAccessController = .shared,
        teamsAccess: TeamsAccessController = .shared
    ) {
        launchAtLogin.refresh()
        assistantStatus.openSettings()
        calendarAccess.openSettings()
        teamsAccess.openSettings()
    }
}
