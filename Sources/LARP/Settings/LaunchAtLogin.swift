import Foundation
import Observation
import ServiceManagement

/// The login item of the app. Replaceable in tests.
protocol LoginItem {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

/// `SMAppService.mainApp`: the app registered to start at login.
struct MainAppLoginItem: LoginItem {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// The "Avvia all'accesso" switch. It is off by default and always reflects the
/// real state of the login item; the state is also kept in `UserDefaults`.
@MainActor
@Observable
final class LaunchAtLogin {
    /// The login item is on (`enabled`) or waiting for the user's approval in
    /// System Settings (`requiresApproval`).
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let item: any LoginItem
    @ObservationIgnored private let defaults: UserDefaults

    init(item: any LoginItem = MainAppLoginItem(), defaults: UserDefaults = .standard) {
        self.item = item
        self.defaults = defaults
        refresh()
    }

    /// Reads the real state of the login item.
    func refresh() {
        let status = item.status
        requiresApproval = status == .requiresApproval
        isEnabled = status == .enabled || requiresApproval
        defaults.set(isEnabled, forKey: SettingsKey.launchAtLogin)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try item.register()
            } else {
                try item.unregister()
            }
        } catch {
            errorMessage = "Impossibile cambiare l'avvio all'accesso: \(error.localizedDescription)"
        }
        refresh()
    }
}
