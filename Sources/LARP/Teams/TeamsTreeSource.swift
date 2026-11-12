import ApplicationServices
import Foundation

/// What one request to Teams returns for one element of its interface.
struct TeamsNodeValues<Node: Sendable>: Sendable {
    /// `AXDOMIdentifier`, the web identifier of the element; `nil` for a native element.
    var identifier: String?
    var title: String?
    var description: String?
    var value: String?
    var children: [Node] = []
}

/// The interface of Teams as the reading sees it: elements and their attributes. The real source
/// asks the Accessibility API; tests give a fake tree, so the limits, the pacing, the single
/// request to expose the interface and the giving up are tested without Teams.
///
/// Every call blocks while Teams answers, so the reading runs off the main actor.
protocol TeamsTreeSource: Sendable {
    associatedtype Node: Equatable & Sendable

    /// The windows of Teams; `nil` when Teams did not answer, which is not the same as no window.
    func windows() -> [Node]?
    /// The attributes of `node` in one request. A request that fails gives empty values.
    func values(of node: Node) -> TeamsNodeValues<Node>
    /// Asks Teams to expose its interface to assistive apps.
    func exposeInterface()
}

/// One element of Teams as the Accessibility API gives it.
struct AccessibilityNode: Equatable, @unchecked Sendable {
    let element: AXUIElement

    static func == (lhs: AccessibilityNode, rhs: AccessibilityNode) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}

/// The interface of one Teams process through the Accessibility API.
final class AccessibilityTeamsTreeSource: TeamsTreeSource, @unchecked Sendable {
    /// How many seconds a request to Teams may take.
    static let messagingTimeout: Float = 0.25

    private static let attributeNames: [String] = [
        "AXDOMIdentifier", kAXChildrenAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute,
    ]

    private let app: AXUIElement

    init(processIdentifier: pid_t) {
        app = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
    }

    func windows() -> [AccessibilityNode]? {
        guard let windows = Self.copyAttributes(of: app, [kAXWindowsAttribute]).first ?? nil else { return nil }
        return Self.elements(windows)
    }

    func values(of node: AccessibilityNode) -> TeamsNodeValues<AccessibilityNode> {
        // The timeout of the application is not always inherited by its elements.
        AXUIElementSetMessagingTimeout(node.element, Self.messagingTimeout)
        let values = Self.copyAttributes(of: node.element, Self.attributeNames)
        return TeamsNodeValues(
            identifier: values[0] as? String,
            title: values[2] as? String,
            description: values[3] as? String,
            value: values[4] as? String,
            children: Self.elements(values[1]))
    }

    /// Chromium builds the tree of its web content only for an assistive client. Both calls
    /// answer with an error but are the signal that makes it do so.
    func exposeInterface() {
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    /// The values of `names` for `element`, in order; `nil` for one that is missing or failed.
    private static func copyAttributes(of element: AXUIElement, _ names: [String]) -> [Any?] {
        var copied: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &copied)
        guard error == .success, let items = copied as? [AnyObject] else {
            return Array(repeating: nil, count: names.count)
        }
        return items.map { item in
            if CFGetTypeID(item) == AXValueGetTypeID(), AXValueGetType(item as! AXValue) == .axError {
                return nil
            }
            return item
        }
    }

    private static func elements(_ value: Any?) -> [AccessibilityNode] {
        guard let items = value as? [AnyObject] else { return [] }
        return items.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? AccessibilityNode(element: item as! AXUIElement) : nil
        }
    }
}
