import CoreAudio
import Foundation
import Synchronization

/// What `MicrophoneCapture` asks Core Audio about the audio output; replaced in tests by fake
/// devices. Only the default output and its sample rate matter: the echo canceller learns the
/// echo path of the output in use.
protocol OutputDevices: Sendable {
    /// Calls `handler`, from a private queue, whenever the default output device or its sample
    /// rate changes, until the returned observation is cancelled.
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation
}

/// `OutputDevices` on Core Audio.
struct CoreAudioOutputDevices: OutputDevices {
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation {
        let observation = OutputObservation(handler: handler)
        observation.start()
        return observation
    }

    /// Listeners on the default output device and, once there is one, on its sample rate. A
    /// notification that changes neither does not reach the handler.
    private final class OutputObservation: InputDevicesObservation, @unchecked Sendable {
        private struct State {
            var output: AudioDeviceID?
            var rate: Float64?
            var rateListeners: PropertyListeners?
            var cancelled = false
        }

        private struct Plan {
            var idChanged: Bool
            var retired: PropertyListeners?
        }

        private let handler: @Sendable () -> Void
        private let state = Mutex(State())
        private var defaultListeners: PropertyListeners?

        init(handler: @escaping @Sendable () -> Void) {
            self.handler = handler
        }

        /// Called once, right after `init`.
        func start() {
            let listeners = PropertyListeners(label: "com.larp.LARP.microphone.output") { [weak self] in self?.refresh(notify: true) }
            defaultListeners = listeners
            listeners.add(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
            refresh(notify: false)
            // What changed while the listeners were being set up is not reported by them.
            listeners.queue.async { [self] in refresh(notify: true) }
        }

        func cancel() {
            let (rate, cancelled) = state.withLock { state -> (PropertyListeners?, Bool) in
                defer {
                    state.cancelled = true
                    state.rateListeners = nil
                }
                return (state.rateListeners, state.cancelled)
            }
            guard !cancelled else { return }
            rate?.stop()
            defaultListeners?.stop()
        }

        private func refresh(notify: Bool) {
            let output = CoreAudioProperty.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
            let rate = output.flatMap {
                CoreAudioProperty.value($0, kAudioDevicePropertyNominalSampleRate, initial: Float64(0))
            }
            let plan = state.withLock { state -> Plan? in
                guard !state.cancelled, state.output != output || state.rate != rate else { return nil }
                let idChanged = state.output != output
                state.output = output
                state.rate = rate
                let retired = idChanged ? state.rateListeners : nil
                if idChanged { state.rateListeners = nil }
                return Plan(idChanged: idChanged, retired: retired)
            }
            guard let plan else { return }
            // Listeners are removed and added outside the lock: a handler that is running waits for it.
            plan.retired?.stop()
            if plan.idChanged, let output {
                let fresh = PropertyListeners(label: "com.larp.LARP.microphone.output.rate") { [weak self] in
                    self?.refresh(notify: true)
                }
                fresh.add(output, kAudioDevicePropertyNominalSampleRate)
                let kept = state.withLock { state -> Bool in
                    guard !state.cancelled else { return false }
                    state.rateListeners = fresh
                    return true
                }
                if !kept { fresh.stop() }
            }
            if notify { handler() }
        }
    }
}
