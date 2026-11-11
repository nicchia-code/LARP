---
description: Use when changing how LARP reads Microsoft Teams through Accessibility or the calendar through EventKit.
---
# Reading Teams and the calendar

## teams-access
- The permission is read with `AXIsProcessTrusted`; "Consenti" calls `AXIsProcessTrustedWithOptions` with the prompt option and opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

## teams-meeting
- Built on the Accessibility API of ApplicationServices: an `AXUIElement` for the running Teams application found through `NSRunningApplication`, its windows walked with a generous node limit (25,000) and early exit at the first marker, an `AXObserver` for window, title, layout and destroyed notifications on the main run loop, and a 2-second timer as the base of correctness; notifications only make a reading come sooner.
- Web elements are matched by their `AXDOMIdentifier`, never by their localised titles or descriptions; when a reading finds no `AXDOMIdentifier` at all, the attributes `AXManualAccessibility` and `AXEnhancedUserInterface` are set on the application element to make Chromium expose its web content, then the tree is read again.
- Readings run off the main actor; their results are handed to the main actor. Teams launching and quitting are followed through the workspace notifications of AppKit.
- The reading of Teams sits behind a protocol, replaced in tests by a fake Teams that emits meetings, people and speakers.

## calendar-access
- Built on EventKit: one `EKEventStore`, `requestFullAccessToEvents` to connect, `authorizationStatus(for: .event)` to read the access, and event predicates over today for "Prossime" and for the event in progress.
- `project.yml` adds `NSCalendarsFullAccessUsageDescription` to the Info properties, in Italian, with the English text in the String Catalog of the Info.plist.
- The calendar sits behind a protocol, replaced in tests by a fake calendar.
