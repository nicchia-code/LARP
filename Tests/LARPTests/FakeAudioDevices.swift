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
/// changes, and every capture labels its buffers with the rate it read when it started.
final class FakeSystemDriver: SystemAudioDriver {
    private final class Capture: SystemAudioHandle, @unchecked Sendable {
        let labelRate: Double
        let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
        let onChange: @Sendable () -> Void
        let active = Mutex(true)

        init(
            labelRate: Double, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
            onChange: @escaping @Sendable () -> Void
        ) {
            self.labelRate = labelRate
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
        var failure: SystemAudioTap.TapError?
        var capture: Capture?
        var observation: Observation?
    }

    let tone: FakeTone
    private let state: Mutex<State>
    /// Captures that started.
    let starts = Counter()
    /// Times the devices were observed because no capture could start.
    let observations = Counter()

    init(tone: FakeTone, rate: Double = 48_000) {
        self.tone = tone
        state = Mutex(State(rate: rate))
    }

    /// Makes the captures fail (or not) from now on.
    func fail(_ failure: SystemAudioTap.TapError?) {
        state.withLock { $0.failure = failure }
    }

    func startCapture(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void, onChange: @escaping @Sendable () -> Void
    ) throws -> any SystemAudioHandle {
        let result = state.withLock { state -> Result<Capture, SystemAudioTap.TapError> in
            if let failure = state.failure { return .failure(failure) }
            let capture = Capture(labelRate: state.rate, deliver: deliver, onChange: onChange)
            state.capture = capture
            return .success(capture)
        }
        let capture = try result.get()
        starts.increment()
        return capture
    }

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
            capture.onChange()
        } else if let observation, observation.active.withLock({ $0 }) {
            observation.onChange()
        }
    }

    /// The device plays `seconds` of the tone at its rate. A running capture hears it,
    /// labelled with the rate it read when it started; with none, the time just passes.
    func play(seconds: Double) {
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
            capture.deliver(buffer, arrival)
        }
    }
}

// MARK: - Microphone

/// The microphone: it runs at `rate`, which a test changes. Its engines keep the rate they
/// were made with, as the input node of an `AVAudioEngine` keeps its format until the engine
/// is reset: only an engine made after the change reads the new rate.
final class FakeMicrophoneDevice: Sendable {
    struct Failure: Error {}

    fileprivate final class Engine: MicrophoneEngine, @unchecked Sendable {
        private struct Running {
            let labelRate: Double
            let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
            let onConfigurationChange: @Sendable () -> Void
        }

        private let device: FakeMicrophoneDevice
        private let readRate: Double
        private let running = Mutex<Running?>(nil)

        init(device: FakeMicrophoneDevice, rate: Double) {
            self.device = device
            readRate = rate
        }

        var isVoiceProcessingEnabled: Bool { false }

        func inputFormat() -> AVAudioFormat {
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: readRate, channels: AVAudioChannelCount(device.tone.channels),
                interleaved: false)!
        }

        func start(
            format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
            onConfigurationChange: @escaping @Sendable () -> Void
        ) throws {
            if device.state.withLock({ $0.fails }) { throw Failure() }
            running.withLock {
                $0 = Running(labelRate: format.sampleRate, deliver: deliver, onConfigurationChange: onConfigurationChange)
            }
            device.starts.increment()
        }

        func stop() { running.withLock { $0 = nil } }

        /// The engine stops itself and tells.
        func configurationChanged() {
            let notify = running.withLock { running -> (@Sendable () -> Void)? in
                defer { running = nil }
                return running?.onConfigurationChange
            }
            notify?()
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

    private struct State {
        var rate: Double
        var fails = false
        var current: Engine?
    }

    let tone: FakeTone
    private let state: Mutex<State>
    /// Engines that started.
    let starts = Counter()

    init(tone: FakeTone, rate: Double = 48_000) {
        self.tone = tone
        state = Mutex(State(rate: rate))
    }

    /// What `MicrophoneCapture` calls to make the engine of a start.
    func makeEngine() -> any MicrophoneEngine {
        state.withLock { state in
            let engine = Engine(device: self, rate: state.rate)
            state.current = engine
            return engine
        }
    }

    /// Makes the engines fail to start (or not) from now on.
    func failToStart(_ fails: Bool) {
        state.withLock { $0.fails = fails }
    }

    /// The microphone changes its sample rate (Bluetooth headphones switching to their call
    /// mode, another microphone): the engine in use stops itself and tells.
    func changeRate(to rate: Double) {
        let engine = state.withLock { state -> Engine? in
            state.rate = rate
            return state.current
        }
        engine?.configurationChanged()
    }

    /// The microphone hears `seconds` of the tone at its rate.
    func play(seconds: Double) {
        var remaining = seconds
        while remaining > 1e-9 {
            let piece = min(remaining, fakeBufferSeconds)
            remaining -= piece
            let (rate, engine) = state.withLock { ($0.rate, $0.current) }
            guard let engine else {
                tone.skip(seconds: piece)
                continue
            }
            engine.play(seconds: piece, rate: rate)
        }
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
