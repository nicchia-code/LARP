// Writes the interface of Microsoft Teams (the new one, `com.microsoft.teams2`) as seen through the
// Accessibility API to a text file, to check the web identifiers LARP reads
// (`call-duration-custom`, `roster-participant`, `active-speaker`) on a real Teams.
//
// Run it with `swift scripts/teams-ax-dump.swift [output file]` from the Terminal while a Teams call
// is going on; the Terminal needs the Accessibility permission (System Settings > Privacy &
// Security > Accessibility). Without an argument the file goes on the Desktop with the date and
// time in its name. It is not part of the app.
//
// Every window of Teams is written as an indented tree. For each element: its role, subrole,
// `AXDOMIdentifier` and `AXDOMClassList`, and only the length in characters of its title,
// description and value, never their text. At most 50,000 elements are visited, each request to
// Teams waits at most 0.25 seconds.

import AppKit
import ApplicationServices

let bundleIdentifier = "com.microsoft.teams2"
let maxElements = 50_000
let messagingTimeout: Float = 0.25

guard AXIsProcessTrusted() else {
    print("The Terminal does not have the Accessibility permission: allow it in System Settings > Privacy & Security > Accessibility, then run the script again.")
    exit(1)
}
guard let teams = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    .first(where: { !$0.isTerminated })
else {
    print("Microsoft Teams (\(bundleIdentifier)) is not running.")
    exit(1)
}

let outputPath: String = {
    if CommandLine.arguments.count > 1 { return (CommandLine.arguments[1] as NSString).expandingTildeInPath }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    return desktop.appendingPathComponent("teams-ax-dump-\(formatter.string(from: Date())).txt").path
}()

let app = AXUIElementCreateApplication(teams.processIdentifier)
AXUIElementSetMessagingTimeout(app, messagingTimeout)

// The same request LARP makes once for each launch of Teams: Chromium builds the tree of its web
// content only for an assistive client.
_ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
_ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
Thread.sleep(forTimeInterval: 1)

let attributeNames: [String] = [
    kAXRoleAttribute, kAXSubroleAttribute, "AXDOMIdentifier", "AXDOMClassList", kAXTitleAttribute,
    kAXDescriptionAttribute, kAXValueAttribute, kAXChildrenAttribute,
]

/// The values of `names` for `element`, in order; `nil` for one that is missing or failed.
func attributes(of element: AXUIElement, _ names: [String]) -> [Any?] {
    AXUIElementSetMessagingTimeout(element, messagingTimeout)
    var copied: CFArray?
    let error = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &copied)
    guard error == .success, let items = copied as? [AnyObject] else {
        return Array(repeating: nil, count: names.count)
    }
    return items.map { item in
        if CFGetTypeID(item) == AXValueGetTypeID(), AXValueGetType(item as! AXValue) == .axError { return nil }
        return item
    }
}

func elements(_ value: Any?) -> [AXUIElement] {
    guard let items = value as? [AnyObject] else { return [] }
    return items.compactMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
}

/// The length of a text attribute, or `-` when the element has none (or it is not text).
func length(_ value: Any?) -> String {
    guard let text = value as? String else { return "-" }
    return String(text.count)
}

var output = ""
var visited = 0
var truncated = false

func dump(_ root: AXUIElement) {
    var stack: [(element: AXUIElement, depth: Int)] = [(root, 0)]
    while let (element, depth) = stack.popLast() {
        guard visited < maxElements else {
            truncated = true
            return
        }
        visited += 1
        let values = attributes(of: element, attributeNames)
        let classList: String
        if let classes = values[3] as? [String] {
            classList = classes.joined(separator: " ")
        } else if let classes = values[3] as? String {
            classList = classes
        } else {
            classList = "-"
        }
        output += String(repeating: "  ", count: depth)
        output += "role=\(values[0] as? String ?? "-") subrole=\(values[1] as? String ?? "-")"
        output += " id=\(values[2] as? String ?? "-") classes=[\(classList)]"
        output += " title=\(length(values[4])) description=\(length(values[5])) value=\(length(values[6]))\n"
        for child in elements(values[7]).reversed() { stack.append((child, depth + 1)) }
    }
}

let windows = elements(attributes(of: app, [kAXWindowsAttribute])[0])
output += "Microsoft Teams (\(bundleIdentifier)), \(windows.count) windows\n"
output += "Lengths are in characters; `-` means the element has no such text.\n\n"
for (index, window) in windows.enumerated() {
    output += "Window \(index + 1)\n"
    dump(window)
    output += "\n"
    if truncated { break }
}
if truncated { output += "Stopped at \(maxElements) elements.\n" }

do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Written \(visited) elements of \(windows.count) windows to \(outputPath)")
} catch {
    print("Could not write \(outputPath): \(error.localizedDescription)")
    exit(1)
}
