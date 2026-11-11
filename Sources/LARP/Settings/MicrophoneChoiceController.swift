import Foundation
import Observation

/// The `microphone-choice` machine: which microphone is recorded, the default one of the Mac or an
/// input device the user chose.
///
/// The choice lives in `UserDefaults`: the unique identifier of the device in
/// `settings.microphone`, its name in `settings.microphoneName` for when it is not connected;
/// absent means "Predefinito di sistema". A choice made during a recording moves the capture to
/// the microphone at once: the capture reads the choice, and `changes` tells it that it changed.
@MainActor
@Observable
final class MicrophoneChoiceController {
    /// The states of the `microphone-choice` machine.
    enum Choice: Equatable, Sendable {
        /// **System default**: the default microphone of the Mac is recorded and followed.
        case systemDefault
        /// **Chosen microphone**: this input device is recorded whenever it is connected.
        case device(uid: String, name: String)

        /// The unique identifier of the chosen device; `nil` for the system default.
        var uid: String? {
            if case .device(let uid, _) = self { uid } else { nil }
        }
    }

    /// An entry of the list offered to the user.
    struct Option: Identifiable, Equatable, Sendable {
        let choice: Choice
        /// "Predefinito di sistema", the name of a connected device, or "<name> (non collegato)".
        let title: String

        var id: String { choice.uid ?? "" }
    }

    /// The controller shared by the app: the settings page, the popover and the capture read the
    /// same choice.
    static let shared = MicrophoneChoiceController()

    private(set) var choice: Choice
    /// The input devices connected now.
    private(set) var connected: [InputDevice] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let devices: any InputDevices
    @ObservationIgnored private let changed = EventBroadcaster<Void>()
    @ObservationIgnored private var observation: (any InputDevicesObservation)?

    init(defaults: UserDefaults = .standard, devices: any InputDevices = CoreAudioInputDevices()) {
        self.defaults = defaults
        self.devices = devices
        if let uid = defaults.string(forKey: SettingsKey.microphone), !uid.isEmpty {
            choice = .device(uid: uid, name: defaults.string(forKey: SettingsKey.microphoneName) ?? uid)
        } else {
            choice = .systemDefault
        }
        connected = devices.connected()
    }

    /// Follows the connected devices, so the list is always the one of now. Call once, at launch.
    func start() {
        guard observation == nil else { return }
        observation = devices.observeChanges { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Reads the connected input devices again. A chosen device that is connected gives its
    /// current name, kept for when it is not.
    func refresh() {
        connected = devices.connected()
        if case .device(let uid, let name) = choice, let device = connected.first(where: { $0.uid == uid }),
            device.name != name
        {
            choice = .device(uid: uid, name: device.name)
            defaults.set(device.name, forKey: SettingsKey.microphoneName)
        }
    }

    // MARK: List

    /// "Predefinito di sistema" and the input devices connected now, then the chosen one, shown
    /// "<name> (non collegato)", when it is missing.
    var options: [Option] {
        var options = [Option(choice: .systemDefault, title: L10n.string("Predefinito di sistema"))]
        options += connected.map { Option(choice: .device(uid: $0.uid, name: $0.name), title: $0.name) }
        if case .device(let uid, let name) = choice, !connected.contains(where: { $0.uid == uid }) {
            options.append(Option(choice: choice, title: L10n.format("%@ (non collegato)", name)))
        }
        return options
    }

    /// The text of the box that shows the choice.
    var currentTitle: String {
        options.first { $0.choice.uid == choice.uid }?.title ?? L10n.string("Predefinito di sistema")
    }

    // MARK: Events

    /// `user.CHOOSE_MICROPHONE`: a connected input device or "Predefinito di sistema". Every
    /// different choice is saved and a recording in progress moves to it at once; choosing again
    /// what is already chosen changes nothing.
    func choose(_ new: Choice) {
        guard new.uid != choice.uid else { return }
        choice = new
        switch new {
        case .systemDefault:
            defaults.removeObject(forKey: SettingsKey.microphone)
            defaults.removeObject(forKey: SettingsKey.microphoneName)
        case .device(let uid, let name):
            defaults.set(uid, forKey: SettingsKey.microphone)
            defaults.set(name, forKey: SettingsKey.microphoneName)
        }
        changed.emit(())
    }

    /// A new stream that yields every time another microphone is chosen, for the capture.
    var changes: AsyncStream<Void> {
        changed.stream()
    }
}
