import Carbon.HIToolbox
import Foundation

/// The two global keyboard shortcuts of LARP.
enum Shortcut: UInt32, CaseIterable, Sendable {
    /// Starts or stops the recording; accepts the proposal when one is shown.
    case record = 1
    /// Adds a bookmark to the call being recorded or listened to.
    case bookmark = 2

    var settingsKey: String {
        switch self {
        case .record: SettingsKey.shortcutRecord
        case .bookmark: SettingsKey.shortcutBookmark
        }
    }

    var defaultCombination: KeyCombination {
        switch self {
        case .record: .recordDefault
        case .bookmark: .bookmarkDefault
        }
    }

    var other: Shortcut {
        switch self {
        case .record: .bookmark
        case .bookmark: .record
        }
    }
}

/// Registers key combinations with macOS so that they work whatever app is in front.
/// Sits behind a protocol so that tests replace the system.
@MainActor
protocol HotKeyRegistering: AnyObject {
    /// Called when the combination registered for a shortcut is pressed.
    var onPressed: (@MainActor (Shortcut) -> Void)? { get set }

    /// Registers `combination` for `shortcut`; `false` when macOS refuses it.
    /// A previous registration of the same shortcut is replaced.
    func register(_ combination: KeyCombination, for shortcut: Shortcut) -> Bool

    /// Removes the registration of `shortcut`, if any.
    func unregister(_ shortcut: Shortcut)
}

/// Carbon's `RegisterEventHotKey`: the only system API for global shortcuts that needs
/// neither the Accessibility permission nor a third-party package.
@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {
    /// Signature of the hot keys of LARP ("LARP").
    private static let signature: OSType = 0x4C41_5250

    var onPressed: (@MainActor (Shortcut) -> Void)?

    private var references: [Shortcut: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    func register(_ combination: KeyCombination, for shortcut: Shortcut) -> Bool {
        unregister(shortcut)
        guard installHandler() else { return false }
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: shortcut.rawValue)
        let status = RegisterEventHotKey(
            combination.keyCode, combination.modifiers, id, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return false }
        references[shortcut] = reference
        return true
    }

    func unregister(_ shortcut: Shortcut) {
        guard let reference = references.removeValue(forKey: shortcut) else { return }
        UnregisterEventHotKey(reference)
    }

    fileprivate func pressed(id: UInt32) {
        guard let shortcut = Shortcut(rawValue: id), references[shortcut] != nil else { return }
        onPressed?(shortcut)
    }

    /// Installs, once, the handler of the hot key events of the application.
    private func installHandler() -> Bool {
        if handler != nil { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(), carbonHotKeyHandler, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        return status == noErr
    }
}

/// Carbon delivers the hot key events on the main thread, with a plain C function.
private func carbonHotKeyHandler(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    let pressedID = id.id
    Task { @MainActor in registrar.pressed(id: pressedID) }
    return noErr
}
