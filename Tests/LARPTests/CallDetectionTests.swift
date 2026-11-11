import Foundation
import Testing

@testable import LARP

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

private let zoom = KnownCallApps.app(forBundleIdentifier: "us.zoom.xos")!
private let teams = KnownCallApps.app(forBundleIdentifier: "com.microsoft.teams2")!
private let slack = KnownCallApps.app(forBundleIdentifier: "com.tinyspeck.slackmacgap")!

/// The next value of a stream, or `nil` when none was emitted already.
private func next<Element: Sendable>(of stream: AsyncStream<Element>) async -> Element? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}

/// The `call-detection` machine: whether the call apps are detected and which are watched.
@MainActor
struct CallDetectionTests {
    @Test func detectionIsOnAndEveryAppWatchedByDefault() {
        let controller = CallDetectionController(defaults: makeDefaults())
        #expect(controller.state == .on)
        #expect(controller.isOn)
        #expect(KnownCallApps.all.allSatisfy { controller.isWatched($0) })
    }

    @Test func turningDetectionOffSavesTheChoice() {
        let defaults = makeDefaults()
        let controller = CallDetectionController(defaults: defaults)
        controller.turnOff()
        #expect(controller.state == .off)
        #expect(defaults.object(forKey: SettingsKey.callDetection) as? Bool == false)
        #expect(CallDetectionController(defaults: defaults).state == .off)

        controller.turnOn()
        #expect(controller.state == .on)
        #expect(CallDetectionController(defaults: defaults).state == .on)
    }

    @Test func unwatchingAnAppSavesItsNameAndWatchingRemovesIt() {
        let defaults = makeDefaults()
        let controller = CallDetectionController(defaults: defaults)
        controller.unwatch(zoom)
        controller.unwatch(teams)
        #expect(!controller.isWatched(zoom) && !controller.isWatched(teams) && controller.isWatched(slack))
        // In the order of the table of known apps.
        #expect(defaults.stringArray(forKey: SettingsKey.unwatchedCallApps) == ["Zoom", "Microsoft Teams"])
        #expect(!CallDetectionController(defaults: defaults).isWatched(zoom))

        controller.watch(zoom)
        #expect(controller.isWatched(zoom))
        #expect(defaults.stringArray(forKey: SettingsKey.unwatchedCallApps) == ["Microsoft Teams"])
    }

    @Test func theChoiceOfAnAppIsSavedAlsoWhileDetectionIsOff() {
        let defaults = makeDefaults()
        let controller = CallDetectionController(defaults: defaults)
        controller.turnOff()
        controller.unwatch(zoom)
        #expect(!controller.isWatched(zoom))
        #expect(controller.state == .off)
        #expect(defaults.stringArray(forKey: SettingsKey.unwatchedCallApps) == ["Zoom"])
        controller.turnOn()
        #expect(!controller.isWatched(zoom))
    }

    @Test func aNameNoLongerKnownIsIgnored() {
        let defaults = makeDefaults()
        defaults.set(["Zoom", "Skype"], forKey: SettingsKey.unwatchedCallApps)
        let controller = CallDetectionController(defaults: defaults)
        #expect(controller.unwatchedNames == ["Zoom"])
        #expect(controller.isWatched(teams))
    }

    @Test func theNewsOfEachEventIsBroadcast() async {
        let controller = CallDetectionController(defaults: makeDefaults())
        let turnedOff = controller.turnOffEvents
        let turnedOn = controller.turnOnEvents
        let unwatched = controller.unwatchEvents
        let watched = controller.watchEvents
        controller.turnOff()
        controller.turnOn()
        controller.unwatch(zoom)
        controller.watch(zoom)
        #expect(await next(of: turnedOff) != nil)
        #expect(await next(of: turnedOn) != nil)
        #expect(await next(of: unwatched) == zoom)
        #expect(await next(of: watched) == zoom)
    }

    @Test func eventsThatChangeNothingAreNotBroadcast() async {
        let controller = CallDetectionController(defaults: makeDefaults())
        let turnedOn = controller.turnOnEvents
        let watched = controller.watchEvents
        // Already on, already watched.
        controller.turnOn()
        controller.watch(zoom)
        controller.turnOff()
        controller.turnOn()
        // Only the second turn-on was news; nothing was said about the watched app.
        #expect(await next(of: turnedOn) != nil)
        controller.unwatch(zoom)
        controller.watch(zoom)
        #expect(await next(of: watched) == zoom)
    }
}

/// The `auto-recording` machine.
@MainActor
struct AutoRecordingTests {
    @Test func itIsOffByDefaultAndTheChoiceIsSaved() {
        let defaults = makeDefaults()
        let controller = AutoRecordingController(defaults: defaults)
        #expect(controller.state == .off)
        #expect(!controller.isOn)

        controller.turnOn()
        #expect(controller.isOn)
        #expect(defaults.bool(forKey: SettingsKey.autoRecording))
        #expect(AutoRecordingController(defaults: defaults).isOn)

        controller.turnOff()
        #expect(!controller.isOn)
        #expect(!defaults.bool(forKey: SettingsKey.autoRecording))
        #expect(!AutoRecordingController(defaults: defaults).isOn)
    }
}
