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
    private var activeBundles: Set<String> = []
    /// The processes using the microphone, with what was read about them when they started, so
    /// that the line of their stop tells the same.
    private var micProcesses: [AudioObjectID: CallAppAttribution] = [:]
    private var currentToken: Token?
    private let processInfo: any ProcessInfoReading
    private let log: @Sendable (String) -> Void

    /// - Parameters:
    ///   - processInfo: where the responsible process, the parents and the bundle identifiers are read.
    ///   - log: receives the lines of the area `detection` of the diagnostic log.
    init(
        processInfo: any ProcessInfoReading = SystemProcessInfoReader(),
        log: @escaping @Sendable (String) -> Void = { DiagnosticLog.write(area: .detection, $0) }
    ) {
        self.processInfo = processInfo
        self.log = log
    }

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
        activeBundles.removeAll()
        micProcesses.removeAll()
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

        let running = Set(processes.filter { CoreAudioProcesses.isRunningInput($0) })
        for process in micProcesses.keys.sorted() where !running.contains(process) {
            if let attribution = micProcesses.removeValue(forKey: process) {
                log("process object \(process) stopped using the microphone: \(attribution.logDescription)")
            }
        }
        for process in running.sorted() where micProcesses[process] == nil {
            let attribution = CallAppAttribution.resolve(
                pid: CoreAudioProcesses.pid(of: process),
                coreAudioBundleIdentifier: CoreAudioProcesses.bundleIdentifier(of: process),
                reader: processInfo
            )
            micProcesses[process] = attribution
            log("process object \(process) started using the microphone: \(attribution.logDescription)")
        }
        let nowActive = Set(micProcesses.values.compactMap(\.app))
        for app in nowActive.subtracting(activeApps).sorted(by: { $0.name < $1.name }) {
            continuation.yield(.started(app))
        }
        for app in activeApps.subtracting(nowActive).sorted(by: { $0.name < $1.name }) {
            continuation.yield(.stopped(app))
        }
        activeApps = nowActive

        let nowActiveBundles = Set(micProcesses.values.compactMap(\.matchedBundleIdentifier))
        for bundle in nowActiveBundles.subtracting(activeBundles).sorted() {
            continuation.yield(.bundleStarted(bundle))
        }
        for bundle in activeBundles.subtracting(nowActiveBundles).sorted() {
            continuation.yield(.bundleStopped(bundle))
        }
        activeBundles = nowActiveBundles
    }
}
