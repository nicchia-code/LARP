import Foundation

/// An app that can host a call.
struct CallApp: Hashable, Sendable {
    /// Display name shown in the proposal.
    let name: String
    /// Bundle identifiers of the app itself; also matches their helper processes
    /// (`<bundle identifier>.<suffix>`, for example `com.google.Chrome.helper`).
    let bundleIdentifiers: [String]
    /// Bundle identifiers of helper processes that do not start with the app's own.
    var helperBundleIdentifiers: [String] = []
}

/// The call apps LARP knows about. This is the single place to extend when a new
/// call app has to be recognized.
enum KnownCallApps {
    static let all: [CallApp] = [
        CallApp(name: "Zoom", bundleIdentifiers: ["us.zoom.xos"]),
        CallApp(name: "Microsoft Teams", bundleIdentifiers: ["com.microsoft.teams2", "com.microsoft.teams"]),
        CallApp(name: "FaceTime", bundleIdentifiers: ["com.apple.FaceTime"]),
        CallApp(name: "Slack", bundleIdentifiers: ["com.tinyspeck.slackmacgap"]),
        CallApp(name: "Discord", bundleIdentifiers: ["com.hnc.Discord"]),
        CallApp(name: "Webex", bundleIdentifiers: ["Cisco-Systems.Spark", "com.webex.meetingmanager"]),
        CallApp(name: "Safari", bundleIdentifiers: ["com.apple.Safari"]),
        CallApp(name: "Chrome", bundleIdentifiers: ["com.google.Chrome"]),
        CallApp(name: "Edge", bundleIdentifiers: ["com.microsoft.edgemac"]),
        CallApp(
            name: "Firefox",
            bundleIdentifiers: ["org.mozilla.firefox"],
            helperBundleIdentifiers: ["org.mozilla.plugincontainer"]
        ),
        CallApp(name: "Arc", bundleIdentifiers: ["company.thebrowser.Browser"]),
        CallApp(name: "Brave", bundleIdentifiers: ["com.brave.Browser"]),
    ]

    /// The call app a process with this bundle identifier belongs to: the app
    /// itself or one of its helper processes. `nil` if it is not a known call app.
    static func app(forBundleIdentifier bundleIdentifier: String, in apps: [CallApp] = all) -> CallApp? {
        apps.first { app in
            app.helperBundleIdentifiers.contains(bundleIdentifier)
                || app.bundleIdentifiers.contains { bundleIdentifier == $0 || bundleIdentifier.hasPrefix($0 + ".") }
        }
    }
}
