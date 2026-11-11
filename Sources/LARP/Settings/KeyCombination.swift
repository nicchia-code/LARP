import AppKit
import Carbon.HIToolbox

/// A key and its modifiers, as Carbon's `RegisterEventHotKey` takes them.
struct KeyCombination: Equatable, Hashable, Sendable {
    /// Virtual key code (`kVK_*`).
    let keyCode: UInt32
    /// Carbon modifier mask: `cmdKey`, `shiftKey`, `optionKey`, `controlKey`.
    let modifiers: UInt32

    static let recordDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(optionKey | cmdKey))
    static let bookmarkDefault = KeyCombination(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(optionKey | cmdKey))

    /// The combination of a key press.
    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        self.keyCode = UInt32(event.keyCode)
        self.modifiers = Self.carbonModifiers(event.modifierFlags)
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }

    // MARK: Storage

    /// The stored value of a shortcut: `<key code>:<modifiers>`, `"none"` for no combination.
    static let noneStoredValue = "none"

    var storedValue: String { "\(keyCode):\(modifiers)" }

    /// Reads a stored value: `.some(nil)` for `"none"`, `nil` when it is not a stored combination.
    static func parse(stored value: String) -> KeyCombination?? {
        if value == noneStoredValue { return .some(nil) }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let key = UInt32(parts[0]), let modifiers = UInt32(parts[1]) else {
            return nil
        }
        return .some(KeyCombination(keyCode: key, modifiers: modifiers))
    }

    // MARK: Display

    /// The keys as shown to the user, modifiers first: `⌥⌘R`.
    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + (Self.keyNames[Int(keyCode)] ?? "#\(keyCode)")
    }

    private static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
        kVK_Space: "Spazio", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
