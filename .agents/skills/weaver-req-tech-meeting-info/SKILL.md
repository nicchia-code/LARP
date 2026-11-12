---
name: weaver-req-tech-meeting-info
description: "Use when changing how LARP reads Microsoft Teams through Accessibility or the calendar through EventKit."
---

# Technology and constraints

## teams-access

- The permission is read with `AXIsProcessTrusted`; "Consenti" calls `AXIsProcessTrustedWithOptions` with the prompt option and opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

## teams-meeting

- Built on the Accessibility API of ApplicationServices: an `AXUIElement` for the running Teams application found through `NSRunningApplication`, an `AXObserver` only for `kAXWindowCreatedNotification` and `kAXTitleChangedNotification` on the main run loop (no layout or destroyed notifications), and a 2-second timer as the base of correctness; notifications only make a reading come sooner. The observer and the timer exist only while the reading is needed; whether it is needed follows the call app detection (Microsoft Teams using the microphone) and the start and end of recordings.
- Each element costs one request: `AXUIElementCopyMultipleAttributeValues` for the attributes the walk needs. `AXUIElementSetMessagingTimeout` of 0.25 seconds is set on the application element and on every element before it is read. The walk counts elements and time across windows (5,000 elements, 1 second) and stops at either limit; once the window holding the meeting marker is found, its `AXUIElement` is kept and walked alone while it is still among the windows of Teams.
- A reading can be cancelled: the walk checks between elements whether it has been cancelled, and stopping the reading, Teams quitting or a new launch of Teams cancels it, so that two walks never run at the same time.
- Web elements are matched by their `AXDOMIdentifier`, never by their localised titles or descriptions; when a reading finds no `AXDOMIdentifier` at all, the attributes `AXManualAccessibility` and `AXEnhancedUserInterface` are set on the application element to make Chromium expose its web content, then the tree is read again; this is remembered for each process identifier of Teams and never repeated for the same process, and a process given up after 3 readings without identifiers is remembered the same way.
- Readings run off the main actor; their results are handed to the main actor. Teams launching and quitting are followed through the workspace notifications of AppKit.
- The walk over the Accessibility tree sits behind a protocol of elements and attributes, so that the limits, the pacing, the single expose request and the giving up are tested with a fake tree.
- Each reading writes one line to the diagnostic log of LARP, area `teams`: its duration in milliseconds, the elements and windows visited, whether it stopped at the limit of elements or of time, whether the expose request was made, whether the meeting marker was found, how many participant elements and speaker marks were found, and the pause before the next reading. A line is also written when the reading of Teams starts or stops and why, and when a launch of Teams is given up. Never a title, a name or any other text read from Teams.
- A verification script, `scripts/teams-ax-dump.swift`, run with `swift` from the Terminal during a Teams call (the Terminal needs the Accessibility permission), finds the running Teams (`com.microsoft.teams2`), makes the same expose request once, and writes to a text file (a path given as argument, by default on the Desktop with the date and time in its name) every window of Teams as an indented tree: for each element its role, subrole, `AXDOMIdentifier` and `AXDOMClassList`, and only the length in characters of its title, description and value, never their text. It visits at most 50,000 elements with a messaging timeout of 0.25 seconds, and prints where the file was written. It is not part of the app.
- The reading of Teams sits behind a protocol, replaced in tests by a fake Teams that emits meetings, people and speakers.

## calendar-access

- Built on EventKit: one `EKEventStore`, `requestFullAccessToEvents` to connect, `authorizationStatus(for: .event)` to read the access, and event predicates over today for "Prossime" and for the event in progress.
- `project.yml` adds `NSCalendarsFullAccessUsageDescription` to the Info properties, in Italian, with the English text in the String Catalog of the Info.plist.
- The calendar sits behind a protocol, replaced in tests by a fake calendar.
