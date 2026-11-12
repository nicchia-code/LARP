import Foundation
import Testing

@testable import LARP

/// Process information made up for a test: pid → (parent, responsible, bundle identifier).
private struct FakeProcessInfo: ProcessInfoReading {
    var parents: [pid_t: pid_t] = [:]
    var responsibles: [pid_t: pid_t] = [:]
    var bundles: [pid_t: String] = [:]

    func responsiblePID(of pid: pid_t) -> pid_t? { responsibles[pid] }
    func parentPID(of pid: pid_t) -> pid_t? { parents[pid] }
    func bundleIdentifier(of pid: pid_t) -> String? { bundles[pid] }
}

private func resolve(
    pid: pid_t? = 100, bundle: String? = nil, _ info: FakeProcessInfo
) -> CallAppAttribution {
    CallAppAttribution.resolve(pid: pid, coreAudioBundleIdentifier: bundle, reader: info)
}

struct ProcessDetectionTests {
    @Test func responsibleAppIsRecognised() {
        // A microphone helper started by the system, not linked to Teams as a child.
        let info = FakeProcessInfo(
            parents: [100: 1], responsibles: [100: 200], bundles: [200: "com.microsoft.teams2"])
        let result = resolve(bundle: "com.apple.audio.helper", info)
        #expect(result.app?.name == "Microsoft Teams")
        #expect(result.responsible == ProcessIdentity(pid: 200, bundleIdentifier: "com.microsoft.teams2"))
        #expect(result.parents.isEmpty)
    }

    @Test func helperWithAnotherAppsIdentifierCountsForTheResponsibleApp() {
        let info = FakeProcessInfo(responsibles: [100: 200], bundles: [200: "com.microsoft.teams2"])
        let result = resolve(bundle: "com.microsoft.edgemac.helper", info)
        #expect(result.app?.name == "Microsoft Teams")
    }

    @Test func responsibleAppIsNotItselfTheProcess() {
        // The process is its own responsible: its Core Audio identifier counts.
        let info = FakeProcessInfo(parents: [100: 1], responsibles: [100: 100])
        let result = resolve(bundle: "us.zoom.xos", info)
        #expect(result.app?.name == "Zoom")
        #expect(result.responsible == ProcessIdentity(pid: 100, bundleIdentifier: "us.zoom.xos"))
    }

    @Test func missingResponsibleFallsBackToOwnIdentifier() {
        let info = FakeProcessInfo(parents: [100: 1])
        #expect(resolve(bundle: "com.apple.FaceTime", info).app?.name == "FaceTime")
        #expect(resolve(bundle: "com.apple.FaceTime", info).responsible == nil)
    }

    @Test func unrecognisedResponsibleFallsBackToPrefixAndHelperIdentifiers() {
        let info = FakeProcessInfo(
            parents: [100: 1], responsibles: [100: 200], bundles: [200: "com.apple.Terminal"])
        let prefixed = resolve(bundle: "com.google.Chrome.helper", info)
        #expect(prefixed.app?.name == "Chrome")
        #expect(prefixed.responsible == ProcessIdentity(pid: 200, bundleIdentifier: "com.apple.Terminal"))
        #expect(resolve(bundle: "org.mozilla.plugincontainer", info).app?.name == "Firefox")
    }

    @Test func responsibleWithoutBundleIdentifierFallsBack() {
        let info = FakeProcessInfo(parents: [100: 1], responsibles: [100: 200])
        #expect(resolve(bundle: "us.zoom.xos", info).app?.name == "Zoom")
    }

    @Test func parentsAreWalkedWhenNothingElseMatches() {
        let info = FakeProcessInfo(
            parents: [100: 110, 110: 120, 120: 1],
            responsibles: [100: 100],
            bundles: [110: "com.apple.Music", 120: "com.tinyspeck.slackmacgap"])
        let result = resolve(bundle: nil, info)
        #expect(result.app?.name == "Slack")
        #expect(result.walkEnd == .matchedParent)
        #expect(result.parents.map(\.pid) == [110, 120])
    }

    @Test func firstAppInTheTableWins() {
        // Responsible is Edge, parent is Teams: the responsible comes first.
        let info = FakeProcessInfo(
            parents: [100: 110, 110: 1], responsibles: [100: 200],
            bundles: [200: "com.microsoft.edgemac", 110: "com.microsoft.teams2"])
        #expect(resolve(bundle: nil, info).app?.name == "Edge")
    }

    @Test func walkStopsAtIdentifierOneOrLower() {
        for root: pid_t in [1, 0] {
            let info = FakeProcessInfo(parents: [100: 110, 110: root], bundles: [110: "com.apple.Music"])
            let result = resolve(bundle: nil, info)
            #expect(result.app == nil)
            #expect(result.walkEnd == .reachedRoot(pid: root))
            #expect(result.parents.map(\.pid) == [110])
        }
    }

    @Test func walkStopsWhenAParentCannotBeRead() {
        let info = FakeProcessInfo(parents: [100: 110], bundles: [110: "com.apple.Music"])
        let result = resolve(bundle: nil, info)
        #expect(result.app == nil)
        #expect(result.walkEnd == .parentUnreadable(pid: 110))
    }

    @Test func walkLooksAtEightLevelsAtMost() {
        // 100 → 101 → … → 110; Zoom is the ninth parent.
        var parents: [pid_t: pid_t] = [:]
        for pid: pid_t in 100..<110 { parents[pid] = pid + 1 }
        let ninth = FakeProcessInfo(parents: parents, bundles: [109: "us.zoom.xos"])
        let beyond = resolve(bundle: nil, ninth)
        #expect(beyond.app == nil)
        #expect(beyond.walkEnd == .levelLimit)
        #expect(beyond.parents.count == 8)

        let eighth = FakeProcessInfo(parents: parents, bundles: [108: "us.zoom.xos"])
        let within = resolve(bundle: nil, eighth)
        #expect(within.app?.name == "Zoom")
        #expect(within.parents.count == 8)
    }

    @Test func unknownPIDHasNoWalk() {
        let result = resolve(pid: nil, bundle: "com.apple.Music", FakeProcessInfo())
        #expect(result.app == nil)
        #expect(result.walkEnd == .unknownPID)
        #expect(resolve(pid: nil, bundle: "us.zoom.xos", FakeProcessInfo()).app?.name == "Zoom")
    }

    @Test func logLineTellsTheDetails() {
        let info = FakeProcessInfo(
            parents: [100: 110, 110: 1], responsibles: [100: 200],
            bundles: [200: "com.apple.Terminal", 110: "com.apple.Music"])
        let line = resolve(bundle: "com.example.helper", info).logDescription
        #expect(line.contains("pid 100"))
        #expect(line.contains("\"com.example.helper\""))
        #expect(line.contains("responsible 200 \"com.apple.Terminal\""))
        #expect(line.contains("1: 110 \"com.apple.Music\""))
        #expect(line.contains("parent has identifier 1"))
        #expect(line.contains("call app: none"))
    }
}

/// The reader that asks macOS, on the process running the tests.
struct SystemProcessInfoReaderTests {
    @Test func readsTheOwnProcess() {
        let reader = SystemProcessInfoReader()
        let own = ProcessInfo.processInfo.processIdentifier
        #expect(reader.parentPID(of: own) == getppid())
        // This macOS exports the responsibility function: the own process has a responsible process.
        let responsible = reader.responsiblePID(of: own)
        #expect(responsible != nil && responsible! > 0)
        #expect(reader.responsiblePID(of: 999_999) == nil)
        #expect(reader.bundleIdentifier(of: own) != nil)
        #expect(reader.parentPID(of: 999_999) == nil)
    }

    @Test func triesTheWrittenNameThenTheRealOne() {
        let marker = UnsafeMutableRawPointer(bitPattern: 0x10)!
        var asked: [String] = []
        let found = SystemProcessInfoReader.firstSymbol(in: SystemProcessInfoReader.responsibilitySymbolNames) { name in
            asked.append(name)
            return name == "responsibility_get_pid_responsible_for_pid" ? marker : nil
        }
        #expect(found == marker)
        #expect(asked == ["responsibility_get_pid_for_pid", "responsibility_get_pid_responsible_for_pid"])

        var askedFirstFound: [String] = []
        let first = SystemProcessInfoReader.firstSymbol(in: SystemProcessInfoReader.responsibilitySymbolNames) { name in
            askedFirstFound.append(name)
            return marker
        }
        #expect(first == marker)
        #expect(askedFirstFound == ["responsibility_get_pid_for_pid"])

        #expect(SystemProcessInfoReader.firstSymbol(in: SystemProcessInfoReader.responsibilitySymbolNames) { _ in nil } == nil)
    }
}
