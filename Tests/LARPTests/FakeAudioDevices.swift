import AVFoundation
import Foundation
import Synchronization

@testable import LARP

// Fake audio devices for the tests that change the sample rate during a recording. They
// deliver a tone of known frequency on a virtual clock (no real time passes), so a test
// waits for the effect it checks and never for a fixed time.

/// A counter a test can wait on.
final class Counter: Sendable {
    private let state = Mutex<(value: Int, waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)])>(
        (0, []))

    var value: Int { state.withLock { $0.value } }

    func increment() {
        let ready = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.value += 1
            let value = state.value
            let done = state.waiters.filter { $0.count <= value }.map(\.continuation)
            state.waiters.removeAll { $0.count <= value }
            return done
        }
        for continuation in ready { continuation.resume() }
    }

    /// Returns when the counter has reached `count`.
    func wait(atLeast count: Int) async {
        await withCheckedContinuation { continuation in
            let reached = state.withLock { state -> Bool in
                if state.value >= count { return true }
                state.waiters.append((count, continuation))
                return false
            }
            if reached { continuation.resume() }
        }
    }
}

/// The events of a capture, in order.
final class EventLog: Sendable {
    private let stored = Mutex<[CaptureEvent]>([])
    private let counter = Counter()

    var events: [CaptureEvent] { stored.withLock { $0 } }

    func append(_ event: CaptureEvent) {
        stored.withLock { $0.append(event) }
        counter.increment()
    }

    /// Returns when `count` events have arrived.
    func wait(forCount count: Int) async { await counter.wait(atLeast: count) }
}

/// A tone of known frequency on a virtual clock: what a device hears, whatever its sample
/// rate is at the moment. The clock only moves when audio is made or skipped.
final class FakeTone: Sendable {
    let frequency: Double
    let channels: Int
    /// The system uptime of the start of the tone.
    let start: TimeInterval
    private let elapsedSeconds = Mutex(0.0)

    init(frequency: Double, channels: Int, start: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.frequency = frequency
        self.channels = channels
        self.start = start
    }

    var elapsed: Double { elapsedSeconds.withLock { $0 } }

    /// The next `seconds` of the tone as a device running at `rate` hears it. The buffer is
    /// labelled with `labelRate`: a device that tells a sample rate other than the one it
    /// runs at makes audio that plays at the wrong speed. `arrival` is the uptime of its
    /// last frame.
    func next(seconds: Double, rate: Double, labelRate: Double) -> (buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        let frames = Int((rate * seconds).rounded())
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: labelRate, channels: AVAudioChannelCount(channels), interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let begin = elapsedSeconds.withLock { elapsed -> Double in
            defer { elapsed += Double(frames) / rate }
            return elapsed
        }
        for channel in 0..<channels {
            for index in 0..<frames {
                let time = begin + Double(index) / rate
                buffer.floatChannelData![channel][index] = Float(0.5 * sin(2 * .pi * frequency * time))
            }
        }
        return (buffer, start + begin + Double(frames) / rate)
    }

    /// Time passes and nothing is heard.
    func skip(seconds: Double) {
        elapsedSeconds.withLock { $0 += seconds }
    }
}

/// How long the fake devices make a buffer.
let fakeBufferSeconds = 0.1

// MARK: - System audio

/// The Core Audio side of the system audio: the output device runs at `rate`, which a test
/// changes, and every capture labels its buffers with the rate its stream really runs at,
/// which is not always the one the tap reports.
final class FakeSystemDriver: SystemAudioDriver {
    private final class Capture: SystemAudioRun, @unchecked Sendable {
        let formats: SystemAudioFormats
        var labelRate: Double { formats.stream.sampleRate }
        let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
        let onChange: @Sendable (_ reason: String) -> Void
        let active = Mutex(true)

        init(
            formats: SystemAudioFormats, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
            onChange: @escaping @Sendable (_ reason: String) -> Void
        ) {
            self.formats = formats
            self.deliver = deliver
            self.onChange = onChange
        }

        func stop() { active.withLock { $0 = false } }
    }

    private final class Observation: SystemAudioHandle, @unchecked Sendable {
        let onChange: @Sendable () -> Void
        let active = Mutex(true)
        init(onChange: @escaping @Sendable () -> Void) { self.onChange = onChange }
        func stop() { active.withLock { $0 = false } }
    }

    private struct State {
        var rate: Double
        var reportedRate: Double?
        var failure: SystemAudioTap.TapError?
        var capture: Capture?
        var observation: Observation?
        var formats: [SystemAudioFormats] = []
    }

    let tone: FakeTone
    private let state: Mutex<State>
    /// Captures that started.
    let starts = Counter()
    /// Times the devices were observed because no capture could start.
    let observations = Counter()

    /// - Parameter reportedRate: the rate the tap reports for itself, when it is not the
    ///   rate its stream runs at (`rate`).
    init(tone: FakeTone, rate: Double = 48_000, reportedRate: Double? = nil) {
        self.tone = tone
        state = Mutex(State(rate: rate, reportedRate: reportedRate))
    }

    /// Makes the captures fail (or not) from now on.
    func fail(_ failure: SystemAudioTap.TapError?) {
        state.withLock { $0.failure = failure }
    }

    func startCapture(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onChange: @escaping @Sendable (_ reason: String) -> Void,
        drops: BufferDrops
    ) throws -> any SystemAudioRun {
        let result = state.withLock { state -> Result<Capture, SystemAudioTap.TapError> in
            if let failure = state.failure { return .failure(failure) }
            // The audio is read at the rate the stream really runs at, whatever the tap reports.
            let capture = Capture(
                formats: SystemAudioFormats(
                    reported: Self.format(rate: state.reportedRate ?? state.rate, channels: tone.channels),
                    stream: Self.format(rate: state.rate, channels: tone.channels)),
                deliver: deliver, onChange: onChange)
            state.capture = capture
            state.formats.append(capture.formats)
            return .success(capture)
        }
        let capture = try result.get()
        starts.increment()
        return capture
    }

    private static func format(rate: Double, channels: Int) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: AVAudioChannelCount(channels), interleaved: false)!
    }

    /// The format the tap reports from now on, when it is not the one of its stream (`nil`:
    /// the same).
    func report(rate: Double?) {
        state.withLock { $0.reportedRate = rate }
    }

    /// The formats of every capture that started, in order.
    var formats: [SystemAudioFormats] { state.withLock { $0.formats } }

    func observeDevices(onChange: @escaping @Sendable () -> Void) -> any SystemAudioHandle {
        let observation = Observation(onChange: onChange)
        state.withLock { $0.observation = observation }
        observations.increment()
        return observation
    }

    /// The output device changes its sample rate: whatever listens is told.
    func changeRate(to rate: Double) {
        state.withLock { $0.rate = rate }
        notify()
    }

    /// The default output device changes, or a device shows up: whatever listens is told.
    func notify() {
        let (capture, observation) = state.withLock { ($0.capture, $0.observation) }
        if let capture, capture.active.withLock({ $0 }) {
            capture.onChange("fake output changed")
        } else if let observation, observation.active.withLock({ $0 }) {
            observation.onChange()
        }
    }

    /// The device plays `seconds` of the tone at its rate (of silence when `silent`: audio
    /// that arrives all the same). A running capture hears it, labelled with the rate it
    /// read when it started; with none, the time just passes.
    func play(seconds: Double, silent: Bool = false) {
        var remaining = seconds
        while remaining > 1e-9 {
            let piece = min(remaining, fakeBufferSeconds)
            remaining -= piece
            let (rate, capture) = state.withLock { ($0.rate, $0.capture) }
            guard let capture, capture.active.withLock({ $0 }) else {
                tone.skip(seconds: piece)
                continue
            }
            let (buffer, arrival) = tone.next(seconds: piece, rate: rate, labelRate: capture.labelRate)
            if silent {
                for channel in 0..<tone.channels {
                    buffer.floatChannelData![channel].update(repeating: 0, count: Int(buffer.frameLength))
                }
            }
            capture.deliver(buffer, arrival)
        }
    }
}

/// The clock of the stall watch of the system audio, which moves only when the test moves it:
/// however busy the machine, the watch fires inside `advance(by:)` and never by itself.
final class ManualStallClock: StallClock {
    private final class Timer: SystemAudioHandle, Sendable {
        private let active = Atomic(true)
        var isActive: Bool { active.load(ordering: .relaxed) }
        func stop() { active.store(false, ordering: .relaxed) }
    }

    private struct Pending: Sendable {
        let deadline: UInt64
        let queue: DispatchQueue
        let fire: @Sendable () -> Void
        let timer: Timer
    }

    private let time = Atomic<UInt64>(0)
    private let pending = Mutex<[Pending]>([])

    func now() -> UInt64 { time.load(ordering: .relaxed) }

    func after(_ seconds: TimeInterval, on queue: DispatchQueue, fire: @escaping @Sendable () -> Void) -> any SystemAudioHandle {
        let timer = Timer()
        let deadline = now() + UInt64((seconds * 1_000_000_000).rounded())
        pending.withLock { $0.append(Pending(deadline: deadline, queue: queue, fire: fire, timer: timer)) }
        return timer
    }

    /// Moves the time on by `seconds`; before returning, runs on their queue every timer due by
    /// then, those they set included, so what a timer starts is already queued after it.
    func advance(by seconds: TimeInterval) {
        let now = time.add(UInt64((seconds * 1_000_000_000).rounded()), ordering: .relaxed).newValue
        while let due = pending.withLock({ pending -> Pending? in
            guard let index = pending.firstIndex(where: { $0.deadline <= now }) else { return nil }
            return pending.remove(at: index)
        }) {
            if due.timer.isActive { due.queue.sync(execute: due.fire) }
        }
    }
}

// MARK: - Microphone

/// The microphone: it runs at `rate`, which a test changes. Its units keep the rate they were
/// made with, as the unit of a start keeps the format it read until it is made again: only a unit
/// made after the change reads the new rate.
final class FakeMicrophoneDevice: Sendable {
    struct Failure: Error {}

    fileprivate final class Unit: MicrophoneUnit, @unchecked Sendable {
        private struct Running {
            let labelRate: Double
            let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
        }

        private let device: FakeMicrophoneDevice
        private let readRate: Double
        private let running = Mutex<Running?>(nil)
        private let handler = Mutex<(@Sendable (MicrophoneUnitChange) -> Void)?>(nil)

        init(device: FakeMicrophoneDevice, rate: Double) {
            self.device = device
            readRate = rate
        }

        var isVoiceProcessingEnabled: Bool { false }

        func inputFormat() -> AVAudioFormat? {
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: readRate, channels: AVAudioChannelCount(device.tone.channels),
                interleaved: false)
        }

        func start(format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) throws {
            if device.state.withLock({ $0.fails }) { throw Failure() }
            running.withLock { $0 = Running(labelRate: format.sampleRate, deliver: deliver) }
            device.starts.increment()
        }

        func stop() { running.withLock { $0 = nil } }

        func observeChanges(_ handler: @escaping @Sendable (MicrophoneUnitChange) -> Void) -> any InputDevicesObservation {
            self.handler.withLock { $0 = handler }
            return Observation { [weak self] in self?.handler.withLock { $0 = nil } }
        }

        /// The listeners of the device in use tell that something changed.
        func notify(_ change: MicrophoneUnitChange) {
            handler.withLock { $0 }?(change)
        }

        func play(seconds: Double, rate: Double) {
            guard let current = running.withLock({ $0 }) else {
                device.tone.skip(seconds: seconds)
                return
            }
            let (buffer, arrival) = device.tone.next(seconds: seconds, rate: rate, labelRate: current.labelRate)
            current.deliver(buffer, arrival)
        }
    }

    private final class Observation: InputDevicesObservation, Sendable {
        private let onCancel: @Sendable () -> Void
        init(_ onCancel: @escaping @Sendable () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }

    private struct State {
        var rate: Double
        var fails = false
        var current: Unit?
    }

    let tone: FakeTone
    private let state: Mutex<State>
    /// Units that started.
    let starts = Counter()

    init(tone: FakeTone, rate: Double = 48_000) {
        self.tone = tone
        state = Mutex(State(rate: rate))
    }

    /// What `MicrophoneCapture` calls to make the unit of a start.
    func makeUnit() -> any MicrophoneUnit {
        state.withLock { state in
            let unit = Unit(device: self, rate: state.rate)
            state.current = unit
            return unit
        }
    }

    /// Makes the units fail to start (or not) from now on.
    func failToStart(_ fails: Bool) {
        state.withLock { $0.fails = fails }
    }

    /// The microphone changes its sample rate (Bluetooth headphones switching to their call
    /// mode, another microphone): the listeners on the device in use tell.
    func changeRate(to rate: Double) {
        let unit = state.withLock { state -> Unit? in
            state.rate = rate
            return state.current
        }
        unit?.notify(.formatChanged)
    }

    /// The microphone disappears: the listeners on the device in use tell.
    func disappear() {
        state.withLock { $0.current }?.notify(.gone)
    }

    /// The microphone hears `seconds` of the tone at its rate.
    func play(seconds: Double) {
        var remaining = seconds
        while remaining > 1e-9 {
            let piece = min(remaining, fakeBufferSeconds)
            remaining -= piece
            let (rate, unit) = state.withLock { ($0.rate, $0.current) }
            guard let unit else {
                tone.skip(seconds: piece)
                continue
            }
            unit.play(seconds: piece, rate: rate)
        }
    }
}

/// The audio output of the Mac as a test sets it: changing it tells the observers, as Core Audio
/// does, from the thread that changed it.
final class FakeOutputDevices: OutputDevices, Sendable {
    private final class Token: InputDevicesObservation, Sendable {
        private let onCancel: @Sendable () -> Void
        init(_ onCancel: @escaping @Sendable () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }

    private let handlers = Mutex<[Int: @Sendable () -> Void]>([:])
    private let next = Mutex(0)

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation {
        let id = next.withLock { value -> Int in
            defer { value += 1 }
            return value
        }
        handlers.withLock { $0[id] = handler }
        return Token { [weak self] in _ = self?.handlers.withLock { $0.removeValue(forKey: id) } }
    }

    /// The number of observers that did not cancel.
    var observerCount: Int { handlers.withLock { $0.count } }

    /// The default output or its sample rate changes.
    func change() {
        let current = handlers.withLock { Array($0.values) }
        for handler in current { handler() }
    }
}

// MARK: - Checking a track

/// What a track received, from the sink after the file.
final class TrackRecorder: AudioBufferSink {
    private let samples = Mutex<[AudioTrack: [Float]]>([:])

    func samples(of track: AudioTrack) -> [Float] { samples.withLock { $0[track] ?? [] } }

    func consume(_ chunk: AudioChunk, track: AudioTrack) {
        guard let data = chunk.buffer.floatChannelData?[0] else { return }
        let received = UnsafeBufferPointer(start: data, count: Int(chunk.buffer.frameLength))
        samples.withLock { $0[track, default: []].append(contentsOf: received) }
    }
}

enum TrackAnalysis {
    /// The frequency of a tone, from its rising zero crossings.
    static func frequency(of samples: ArraySlice<Float>) -> Double {
        var crossings: [Int] = []
        var previous = samples.first ?? 0
        for index in samples.indices.dropFirst() {
            if previous < 0 && samples[index] >= 0 { crossings.append(index) }
            previous = samples[index]
        }
        guard let first = crossings.first, let last = crossings.last, last > first else { return 0 }
        return Double(crossings.count - 1) * AudioFormats.storageSampleRate / Double(last - first)
    }

    /// The samples from `start` to `end` seconds of the track, without `margin` at each end.
    static func window(_ samples: [Float], from start: Double, to end: Double, margin: Double = 0.5) -> ArraySlice<Float> {
        let rate = AudioFormats.storageSampleRate
        let lower = min(samples.count, Int((start + margin) * rate))
        let upper = min(samples.count, Int((end - margin) * rate))
        return samples[lower..<max(lower, upper)]
    }

    static func level(of samples: ArraySlice<Float>) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1))).squareRoot()
    }
}
