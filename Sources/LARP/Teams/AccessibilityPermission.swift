import AppKit
import ApplicationServices

/// The Accessibility permission of macOS, which lets LARP read Microsoft Teams. Replaceable in
/// tests.
protocol AccessibilityPermission: Sendable {
    /// Whether macOS gives LARP the permission now.
    var isGranted: Bool { get }
    /// Asks macOS to prompt the user and opens System Settings › Privacy & Security ›
    /// Accessibility.
    func request()
}

/// The real permission: `AXIsProcessTrusted`; "Consenti" calls `AXIsProcessTrustedWithOptions` with
/// the prompt option and opens the Accessibility pane of System Settings.
struct SystemAccessibilityPermission: AccessibilityPermission {
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var isGranted: Bool { AXIsProcessTrusted() }

    func request() {
        // The prompt option, as the string the constant `kAXTrustedCheckOptionPrompt` holds.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
