import CoreAudio
import Foundation

/// Detects which known call apps use the microphone, from the Core Audio process
/// list. It listens for changes of the list and of each process's
/// `kAudioProcessPropertyIsRunningInput`; it never polls.
///
/// One observation at a time: calling `events()` again ends the previous stream.
final class CoreAudioCallAppMicSource: CallAppMicSource, @unchecked Sendable {
    /// All the state below is confined to `queue`.
    private let queue = DispatchQueue(label: "larp.capture.coreaudio-mic")
    private var continuation: AsyncStream<CallAppMicEvent>.Continuation?
    private var processListListener: AudioObjectPropertyListenerBlock?
    private var inputListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var activeApps: Set<CallApp> = []
    private var currentToken: Token?

    /// Identifies one `events()` stream, so that a stream that was replaced does
    /// not stop its successor when it terminates.
    private final class Token: Sendable {}

    func events() -> AsyncStream<CallAppMicEvent> {
        let (stream, continuation) = AsyncStream<CallAppMicEvent>.makeStream(bufferingPolicy: .unbounded)
        let token = Token()
        queue.async { [self] in
            stopObserving()
            currentToken = token
            self.continuation = continuation
            startObserving()
        }
        continuation.onTermination = { [self] _ in
            queue.async { [self] in
                // A newer `events()` call may already have replaced this stream.
                if currentToken === token { stopObserving() }
            }
        }
        return stream
    }

    // MARK: - Queue-confined

    private func startObserving() {
        let listener: AudioObjectPropertyListenerBlock = { [self] _, _ in refresh() }
        processListListener = listener
        var address = CoreAudioProcesses.processListAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
        refresh()
    }

    private func stopObserving() {
        guard continuation != nil else { return }
        var address = CoreAudioProcesses.processListAddress
        if let listener = processListListener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
        }
        processListListener = nil
        var inputAddress = CoreAudioProcesses.isRunningInputAddress
        for (process, listener) in inputListeners {
            AudioObjectRemovePropertyListenerBlock(process, &inputAddress, queue, listener)
        }
        inputListeners.removeAll()
        activeApps.removeAll()
        continuation?.finish()
        continuation = nil
        currentToken = nil
    }

    /// Aligns the per-process listeners with the process list, then reports which
    /// call apps started or stopped using the microphone since the last time.
    private func refresh() {
        guard let continuation else { return }
        let processes = CoreAudioProcesses.processObjects()
        let current = Set(processes)

        var inputAddress = CoreAudioProcesses.isRunningInputAddress
        for process in inputListeners.keys where !current.contains(process) {
            if let listener = inputListeners.removeValue(forKey: process) {
                AudioObjectRemovePropertyListenerBlock(process, &inputAddress, queue, listener)
            }
        }
        for process in processes where inputListeners[process] == nil {
            let listener: AudioObjectPropertyListenerBlock = { [self] _, _ in refresh() }
            inputListeners[process] = listener
            AudioObjectAddPropertyListenerBlock(process, &inputAddress, queue, listener)
        }

        var nowActive: Set<CallApp> = []
        for process in processes where CoreAudioProcesses.isRunningInput(process) {
            if let app = CoreAudioProcesses.callApp(of: process) {
                nowActive.insert(app)
            }
        }
        for app in nowActive.subtracting(activeApps).sorted(by: { $0.name < $1.name }) {
            continuation.yield(.started(app))
        }
        for app in activeApps.subtracting(nowActive).sorted(by: { $0.name < $1.name }) {
            continuation.yield(.stopped(app))
        }
        activeApps = nowActive
    }
}
