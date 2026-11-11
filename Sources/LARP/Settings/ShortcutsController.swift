import Foundation
import Observation

/// The `shortcuts` machine: the two global keyboard shortcuts, each with a key combination
/// or none. The ones with a combination are registered with macOS, again at every change.
///
/// Settings never depends on the call layer: the app entry point passes `start(perform:)`
/// what each shortcut does.
@MainActor
@Observable
final class ShortcutsController {
    /// Why a combination was refused; shown under the row of the shortcut.
    enum Rejection: Sendable, Equatable {
        /// The combination is the one of the other shortcut.
        case usedByOther
        /// macOS refused to register it.
        case unavailable

        var message: String {
            switch self {
            case .usedByOther: "Già usata da un'altra scorciatoia"
            case .unavailable: "Combinazione non disponibile"
            }
        }
    }

    /// The controller shared by the app: the settings window, the buttons that show a
    /// combination and the app entry point read the same instance.
    static let shared = ShortcutsController()

    /// The combination of each shortcut; a shortcut without one is absent.
    private(set) var combinations: [Shortcut: KeyCombination]
    /// The combination refused last for each shortcut, until the next change of it.
    private(set) var rejections: [Shortcut: Rejection] = [:]

    @ObservationIgnored private let registrar: any HotKeyRegistering
    @ObservationIgnored private let defaults: UserDefaults

    init(registrar: any HotKeyRegistering = CarbonHotKeyRegistrar(), defaults: UserDefaults = .standard) {
        self.registrar = registrar
        self.defaults = defaults
        var combinations: [Shortcut: KeyCombination] = [:]
        for shortcut in Shortcut.allCases {
            let stored = defaults.string(forKey: shortcut.settingsKey).flatMap(KeyCombination.parse(stored:))
            switch stored {
            case .some(.some(let combination)): combinations[shortcut] = combination
            case .some(.none): break
            case .none: combinations[shortcut] = shortcut.defaultCombination
            }
        }
        self.combinations = combinations
    }

    func combination(for shortcut: Shortcut) -> KeyCombination? {
        combinations[shortcut]
    }

    /// The keys of the shortcut as shown next to a button; `nil` when it has none.
    func display(for shortcut: Shortcut) -> String? {
        combinations[shortcut]?.displayString
    }

    // MARK: Registration

    /// Registers the shortcuts that have a combination; `perform` runs when one is pressed.
    func start(perform: @escaping @MainActor (Shortcut) -> Void) {
        registrar.onPressed = perform
        register()
    }

    /// Takes the shortcuts away from macOS while the user records a new combination,
    /// so that pressing one of them does not run it.
    func suspend() {
        for shortcut in Shortcut.allCases { registrar.unregister(shortcut) }
    }

    /// Registers the shortcuts again after `suspend()`.
    func resume() {
        register()
    }

    /// Registers each saved combination; one macOS refuses (another app holds it) is shown as
    /// unavailable under its row.
    private func register() {
        for shortcut in Shortcut.allCases {
            registrar.unregister(shortcut)
            guard let combination = combinations[shortcut] else { continue }
            if !registrar.register(combination, for: shortcut) { rejections[shortcut] = .unavailable }
        }
    }

    // MARK: Events

    /// `user.CHANGE_SHORTCUT`: when the combination is not the one of the other shortcut
    /// and macOS accepts it, it is saved and replaces the previous one; otherwise the
    /// shortcut keeps its previous combination and the reason is shown.
    func change(_ shortcut: Shortcut, to combination: KeyCombination) {
        if combinations[shortcut.other] == combination {
            rejections[shortcut] = .usedByOther
            return
        }
        guard registrar.register(combination, for: shortcut) else {
            // The registration of the previous combination was replaced by the attempt.
            if let previous = combinations[shortcut] { _ = registrar.register(previous, for: shortcut) }
            rejections[shortcut] = .unavailable
            return
        }
        combinations[shortcut] = combination
        rejections[shortcut] = nil
        defaults.set(combination.storedValue, forKey: shortcut.settingsKey)
    }

    /// `user.CLEAR_SHORTCUT`: the shortcut has no combination any more; the choice is saved.
    func clear(_ shortcut: Shortcut) {
        registrar.unregister(shortcut)
        combinations[shortcut] = nil
        rejections[shortcut] = nil
        defaults.set(KeyCombination.noneStoredValue, forKey: shortcut.settingsKey)
    }

    /// Forgets the reason a combination was refused, when the user cancels or leaves.
    func dismissRejection(of shortcut: Shortcut) {
        rejections[shortcut] = nil
    }
}
