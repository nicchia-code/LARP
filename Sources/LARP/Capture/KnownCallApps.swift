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

extension KnownCallApps {
    /// The bundle identifier `KnownCallApps` lists for `app` that `bundleIdentifier` is, or is a
    /// helper of: `com.microsoft.teams2.helper` gives `com.microsoft.teams2`, which is not the classic
    /// `com.microsoft.teams`. `nil` when it is none of them.
    static func listedBundleIdentifier(of bundleIdentifier: String, in app: CallApp) -> String? {
        if app.helperBundleIdentifiers.contains(bundleIdentifier) { return bundleIdentifier }
        return app.bundleIdentifiers.first { bundleIdentifier == $0 || bundleIdentifier.hasPrefix($0 + ".") }
    }
}

extension CallAppAttribution {
    /// The bundle identifier, as `KnownCallApps` lists it, of the process the call app was recognised
    /// in: the one macOS holds responsible, the process itself, or a parent, in the order the
    /// attribution looks at them. `nil` when no app was recognised.
    var matchedBundleIdentifier: String? {
        guard let app else { return nil }
        let candidates = [responsible?.bundleIdentifier, coreAudioBundleIdentifier] + parents.map(\.bundleIdentifier)
        return candidates.lazy.compactMap { $0.flatMap { KnownCallApps.listedBundleIdentifier(of: $0, in: app) } }.first
    }
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

/// The links of the known call apps that a calendar event can hold, and the app each belongs to.
/// The names are those of `KnownCallApps` where the app is there ("Google Meet" lives in a
/// browser, so it has no entry of its own).
enum KnownCallLinks {
    static let all: [(domain: String, appName: String)] = [
        ("teams.microsoft.com", "Microsoft Teams"),
        ("teams.live.com", "Microsoft Teams"),
        ("zoom.us", "Zoom"),
        ("meet.google.com", "Google Meet"),
        ("webex.com", "Webex"),
        ("facetime.apple.com", "FaceTime"),
    ]

    /// The call app whose link is in one of `texts`, looked at in order: a domain counts when it
    /// is not the tail of a longer word (`us04web.zoom.us` is Zoom, `notzoom.us` is not).
    static func appName(in texts: [String?]) -> String? {
        for text in texts {
            guard let text, !text.isEmpty else { continue }
            let lowered = text.lowercased()
            for (domain, appName) in all where contains(domain, in: lowered) {
                return appName
            }
        }
        return nil
    }

    private static func contains(_ domain: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while let range = text.range(of: domain, range: searchStart..<text.endIndex) {
            if range.lowerBound == text.startIndex {
                return true
            }
            let before = text[text.index(before: range.lowerBound)]
            if !(before.isLetter || before.isNumber || before == "-") {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }
}
