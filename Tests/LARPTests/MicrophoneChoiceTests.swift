import AVFoundation
import CoreAudio
import Foundation
import Synchronization
import Testing

@testable import LARP

/// The input devices of the Mac as a test sets them. Changing them tells the observers, as
/// Core Audio does, from the thread that changed them.
final class FakeInputDevices: InputDevices, Sendable {
    private struct State {
        var connected: [InputDevice]
        var defaultUID: String?
        var handlers: [Int: @Sendable () -> Void] = [:]
        var nextHandler = 0
    }

    private final class Token: InputDevicesObservation, Sendable {
        private let onCancel: @Sendable () -> Void
        init(_ onCancel: @escaping @Sendable () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }

    private let state: Mutex<State>

    init(connected: [InputDevice], defaultUID: String?) {
        state = Mutex(State(connected: connected, defaultUID: defaultUID))
    }

    func connected() -> [InputDevice] { state.withLock { $0.connected } }

    func systemDefault() -> InputDevice? {
        state.withLock { state in state.connected.first { $0.uid == state.defaultUID } }
    }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation {
        let id = state.withLock { state -> Int in
            defer { state.nextHandler += 1 }
            state.handlers[state.nextHandler] = handler
            return state.nextHandler
        }
        return Token { [weak self] in _ = self?.state.withLock { $0.handlers.removeValue(forKey: id) } }
    }

    /// The number of observers that did not cancel.
    var observerCount: Int { state.withLock { $0.handlers.count } }

    /// The connected devices or the default one change.
    func set(connected: [InputDevice], defaultUID: String?) {
        let handlers = state.withLock { state -> [@Sendable () -> Void] in
            state.connected = connected
            state.defaultUID = defaultUID
            return Array(state.handlers.values)
        }
        for handler in handlers { handler() }
    }
}

let builtInMicrophone = InputDevice(uid: "BuiltInMicrophoneDevice", name: "MacBook Pro Microphone", id: 41)
let usbMicrophone = InputDevice(uid: "AppleUSBAudioEngine:Shure:MV7:1234", name: "Shure MV7", id: 42)

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

/// The machine `microphone-choice`: what is offered, what is saved.
@MainActor
struct MicrophoneChoiceControllerTests {
    private func makeController(
        connected: [InputDevice] = [builtInMicrophone, usbMicrophone], defaults: UserDefaults = makeDefaults()
    ) -> (MicrophoneChoiceController, FakeInputDevices, UserDefaults) {
        let devices = FakeInputDevices(connected: connected, defaultUID: builtInMicrophone.uid)
        return (MicrophoneChoiceController(defaults: defaults, devices: devices), devices, defaults)
    }

    @Test("without a saved choice the system default is recorded")
    func startsOnTheSystemDefault() {
        let (controller, _, _) = makeController()
        #expect(controller.choice == .systemDefault)
        #expect(controller.currentTitle == L10n.string("Predefinito di sistema"))
    }

    @Test("the list holds the system default and the connected input devices")
    func listsTheConnectedDevices() {
        let (controller, _, _) = makeController()
        #expect(
            controller.options.map(\.title) == [L10n.string("Predefinito di sistema"), "MacBook Pro Microphone", "Shure MV7"])
        #expect(controller.options.first?.choice == .systemDefault)
    }

    @Test("a chosen device that is not connected is listed as not connected, after the connected ones")
    func listsTheChosenDeviceWhenMissing() {
        let defaults = makeDefaults()
        defaults.set(usbMicrophone.uid, forKey: SettingsKey.microphone)
        defaults.set(usbMicrophone.name, forKey: SettingsKey.microphoneName)
        let (controller, _, _) = makeController(connected: [builtInMicrophone], defaults: defaults)

        let titles = controller.options.map(\.title)
        #expect(titles.last == L10n.format("%@ (non collegato)", "Shure MV7"))
        #expect(titles.count == 3)
        #expect(controller.currentTitle == L10n.format("%@ (non collegato)", "Shure MV7"))
    }

    @Test("a chosen device that is connected is listed once, with its name")
    func listsTheChosenDeviceOnce() {
        let defaults = makeDefaults()
        defaults.set(usbMicrophone.uid, forKey: SettingsKey.microphone)
        defaults.set("Old name", forKey: SettingsKey.microphoneName)
        let (controller, _, _) = makeController(defaults: defaults)

        #expect(controller.options.count == 3)
        #expect(controller.currentTitle == "Shure MV7")
        controller.refresh()
        #expect(controller.currentTitle == "Shure MV7")
        #expect(defaults.string(forKey: SettingsKey.microphoneName) == "Shure MV7")
    }

    @Test("choosing a device saves its identifier and its name")
    func choosingADeviceIsSaved() {
        let (controller, _, defaults) = makeController()
        controller.choose(.device(uid: usbMicrophone.uid, name: usbMicrophone.name))
        #expect(controller.choice == .device(uid: usbMicrophone.uid, name: "Shure MV7"))
        #expect(defaults.string(forKey: SettingsKey.microphone) == usbMicrophone.uid)
        #expect(defaults.string(forKey: SettingsKey.microphoneName) == "Shure MV7")
    }

    @Test("the saved choice is read again at the next launch")
    func theChoiceSurvivesALaunch() {
        let (controller, _, defaults) = makeController()
        controller.choose(.device(uid: usbMicrophone.uid, name: usbMicrophone.name))
        let (again, _, _) = makeController(defaults: defaults)
        #expect(again.choice == .device(uid: usbMicrophone.uid, name: "Shure MV7"))
    }

    @Test("choosing the system default again takes the saved choice away")
    func choosingTheSystemDefault() {
        let (controller, _, defaults) = makeController()
        controller.choose(.device(uid: usbMicrophone.uid, name: usbMicrophone.name))
        controller.choose(.systemDefault)
        #expect(controller.choice == .systemDefault)
        #expect(defaults.string(forKey: SettingsKey.microphone) == nil)
        #expect(defaults.string(forKey: SettingsKey.microphoneName) == nil)
    }

    @Test("every different choice is announced; choosing what is already chosen changes nothing")
    func announcesOnlyDifferentChoices() async {
        let (controller, _, defaults) = makeController()
        let changes = controller.changes
        var iterator = changes.makeAsyncIterator()

        controller.choose(.systemDefault)
        controller.choose(.device(uid: usbMicrophone.uid, name: usbMicrophone.name))
        controller.choose(.device(uid: usbMicrophone.uid, name: usbMicrophone.name))
        controller.choose(.device(uid: builtInMicrophone.uid, name: builtInMicrophone.name))
        controller.choose(.systemDefault)
        controller.choose(.systemDefault)

        // Three different choices: Shure, built-in, system default.
        for _ in 0..<3 { _ = await iterator.next() }
        #expect(defaults.string(forKey: SettingsKey.microphone) == nil)
    }

    @Test("the list follows the devices that are connected and disconnected")
    func followsTheDevices() async {
        let (controller, devices, _) = makeController()
        controller.start()
        devices.set(connected: [builtInMicrophone], defaultUID: builtInMicrophone.uid)
        for _ in 0..<400 where controller.options.count != 2 { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(controller.options.map(\.title) == [L10n.string("Predefinito di sistema"), "MacBook Pro Microphone"])
    }
}

/// The microphone to use, and the capture that follows it (`microphone`).
@Suite("Microphone choice during a capture", .serialized)
struct MicrophoneChoiceCaptureTests {
    /// A box the closures of the capture read the choice from.
    private final class ChoiceBox: Sendable {
        private let value = Mutex<String?>(nil)
        var uid: String? {
            get { value.withLock { $0 } }
            set { value.withLock { $0 = newValue } }
        }
    }

    private final class Rig: Sendable {
        let devices: FakeInputDevices
        let choice = ChoiceBox()
        /// One fake device per input device, all hearing the same tone on the same clock.
        let tone = FakeTone(frequency: 440, channels: 1)
        let builtIn: FakeMicrophoneDevice
        let usb: FakeMicrophoneDevice
        let events = EventLog()
        let sink = TrackRecorder()
        let pipeline: TrackPipeline
        let microphone: MicrophoneCapture
        let folder: URL

        init(connected: [InputDevice] = [builtInMicrophone, usbMicrophone], chosen: String? = nil) throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: "larp-choice-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
            let devices = FakeInputDevices(connected: connected, defaultUID: builtInMicrophone.uid)
            self.devices = devices
            let builtIn = FakeMicrophoneDevice(tone: tone, rate: 48_000)
            let usb = FakeMicrophoneDevice(tone: tone, rate: 48_000)
            self.builtIn = builtIn
            self.usb = usb
            let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
            self.pipeline = pipeline
            let choice = choice
            choice.uid = chosen
            let events = events
            microphone = MicrophoneCapture(
                pipeline: pipeline, events: { events.append($0) }, inputDevices: devices,
                chosenDevice: { choice.uid },
                makeUnit: { device in
                    (device?.uid ?? devices.systemDefault()?.uid) == usbMicrophone.uid ? usb.makeUnit() : builtIn.makeUnit()
                })
        }

        func choose(_ uid: String?) {
            choice.uid = uid
            microphone.microphoneChoiceChanged()
        }

        func finish() async {
            microphone.stop()
            await pipeline.finish()
            try? FileManager.default.removeItem(at: folder)
        }
    }

    @Test("with the system default the default microphone is recorded")
    func recordsTheDefault() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        #expect(rig.builtIn.starts.value == 1)
        #expect(rig.usb.starts.value == 0)
        await rig.finish()
    }

    @Test("a chosen microphone that is connected is recorded instead of the default one")
    func recordsTheChosenMicrophone() async throws {
        let rig = try Rig(chosen: usbMicrophone.uid)
        try rig.microphone.start()
        #expect(rig.usb.starts.value == 1)
        #expect(rig.builtIn.starts.value == 0)
        await rig.finish()
    }

    @Test("a chosen microphone that is not connected is replaced by the default one")
    func fallsBackToTheDefault() async throws {
        let rig = try Rig(connected: [builtInMicrophone], chosen: usbMicrophone.uid)
        try rig.microphone.start()
        #expect(rig.builtIn.starts.value == 1)
        #expect(rig.usb.starts.value == 0)
        await rig.finish()
    }

    @Test("a choice during a recording moves the capture to the new microphone at once")
    func choiceMovesTheCapture() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.builtIn.play(seconds: 2)
        rig.choose(usbMicrophone.uid)
        #expect(rig.usb.starts.value == 1)
        rig.usb.play(seconds: 2)
        await rig.finish()

        // Both engines started on the same capture: the echo canceller is asked at every start.
        #expect(rig.events.events == [.echoCancellation(available: false), .echoCancellation(available: false)])
        let samples = rig.sink.samples(of: .microphone)
        #expect(abs(Double(samples.count) / AudioFormats.storageSampleRate - 4) < 0.1)
    }

    @Test("a choice that does not change the microphone to use does not restart the capture")
    func choiceOfTheMicrophoneInUse() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        // The default microphone is the built-in one: choosing it changes nothing.
        rig.choose(builtInMicrophone.uid)
        rig.choose(nil)
        #expect(rig.builtIn.starts.value == 1)
        #expect(rig.usb.starts.value == 0)
        await rig.finish()
    }

    @Test("the gap of the restart is filled with silence, so the track keeps the time of the recording")
    func gapIsFilled() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.builtIn.play(seconds: 2)
        // The switch takes three seconds in which nothing is captured.
        rig.tone.skip(seconds: 3)
        rig.choose(usbMicrophone.uid)
        rig.usb.play(seconds: 2)
        await rig.finish()

        let samples = rig.sink.samples(of: .microphone)
        #expect(abs(Double(samples.count) / AudioFormats.storageSampleRate - 7) < 0.2)
        let silence = TrackAnalysis.level(of: TrackAnalysis.window(samples, from: 2, to: 5, margin: 0.2))
        #expect(silence < 0.001)
    }

    @Test("a chosen microphone that is connected again is taken again, and the default one comes back when it goes")
    func followsTheChosenMicrophone() async throws {
        let rig = try Rig(connected: [builtInMicrophone], chosen: usbMicrophone.uid)
        try rig.microphone.start()
        #expect(rig.builtIn.starts.value == 1)

        rig.devices.set(connected: [builtInMicrophone, usbMicrophone], defaultUID: builtInMicrophone.uid)
        #expect(rig.usb.starts.value == 1)

        rig.devices.set(connected: [builtInMicrophone], defaultUID: builtInMicrophone.uid)
        #expect(rig.builtIn.starts.value == 2)
        await rig.finish()
    }

    @Test("a change of the connected devices that does not change the microphone to use does not restart the capture")
    func unrelatedDeviceChange() async throws {
        let rig = try Rig(connected: [builtInMicrophone])
        try rig.microphone.start()
        rig.devices.set(connected: [builtInMicrophone, usbMicrophone], defaultUID: builtInMicrophone.uid)
        #expect(rig.builtIn.starts.value == 1)
        #expect(rig.usb.starts.value == 0)
        await rig.finish()
    }

    @Test("a choice that cannot start makes the microphone lost, and another choice starts it again")
    func lostAndRestoredByChoices() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.usb.failToStart(true)
        rig.choose(usbMicrophone.uid)
        #expect(rig.microphone.isLost)
        #expect(rig.events.events == [.echoCancellation(available: false), .microphoneLost])

        // Still lost: nothing is said.
        rig.choose(usbMicrophone.uid)
        #expect(rig.events.events.count == 2)

        rig.choose(nil)
        #expect(!rig.microphone.isLost)
        #expect(
            rig.events.events == [
                .echoCancellation(available: false), .microphoneLost, .microphoneRestored,
                .echoCancellation(available: false),
            ])
        await rig.finish()
    }

    @Test("from the lost state every change of the connected devices is a chance to start again")
    func lostRestoredByADeviceChange() async throws {
        let rig = try Rig(connected: [builtInMicrophone], chosen: usbMicrophone.uid)
        try rig.microphone.start()
        rig.usb.failToStart(true)
        // The chosen microphone is connected but cannot start: lost.
        rig.devices.set(connected: [builtInMicrophone, usbMicrophone], defaultUID: builtInMicrophone.uid)
        #expect(rig.microphone.isLost)
        #expect(rig.events.events == [.echoCancellation(available: false), .microphoneLost])

        // Another change, and it still cannot start: nothing is said.
        rig.devices.set(connected: [builtInMicrophone, usbMicrophone], defaultUID: usbMicrophone.uid)
        #expect(rig.microphone.isLost)
        #expect(rig.events.events.count == 2)

        // The next one lets it start.
        rig.usb.failToStart(false)
        rig.devices.set(connected: [builtInMicrophone, usbMicrophone], defaultUID: builtInMicrophone.uid)
        #expect(!rig.microphone.isLost)
        #expect(
            rig.events.events == [
                .echoCancellation(available: false), .microphoneLost, .microphoneRestored,
                .echoCancellation(available: false),
            ])
        await rig.finish()
    }

    @Test("stopping the capture stops following the devices")
    func stopRemovesTheObserver() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        #expect(rig.devices.observerCount == 1)
        await rig.finish()
        #expect(rig.devices.observerCount == 0)
    }
}

/// The capture tells the microphone about a new choice.
@Suite("Microphone choice reaches the capture", .serialized)
struct MicrophoneChoiceReachesCaptureTests {
    @Test("the capture passes the news to the microphone of the recording, and only while recording")
    func forwardsToTheMicrophone() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-forward-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let microphone = Mutex<ChoiceCountingMicrophone?>(nil)
        let capture = CallAudioCapture(
            makeMicrophone: { _, _, _ in
                let fake = ChoiceCountingMicrophone()
                microphone.withLock { $0 = fake }
                return fake
            },
            makeSystem: { _, _, _ in QuietSystemAudio() })

        capture.microphoneChoiceChanged()
        try await capture.start(into: folder, sink: nil, systemAudio: .required)
        capture.microphoneChoiceChanged()
        capture.microphoneChoiceChanged()
        let count = try #require(microphone.withLock { $0 }).changes
        await capture.stop()
        capture.microphoneChoiceChanged()

        #expect(count == 2)
        #expect(try #require(microphone.withLock { $0 }).changes == 2)
    }
}

private final class ChoiceCountingMicrophone: MicrophoneSource {
    private let count = Mutex(0)
    var changes: Int { count.withLock { $0 } }
    var isLost: Bool { false }
    func start() throws {}
    func stop() {}
    func microphoneChoiceChanged() { count.withLock { $0 += 1 } }
}

private final class QuietSystemAudio: SystemAudioSource {
    var isLost: Bool { false }
    func start() throws {}
    func stop() {}
}
