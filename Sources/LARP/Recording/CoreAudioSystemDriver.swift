import AVFoundation
import CoreAudio
import Foundation
import Synchronization

/// `SystemAudioDriver` on Core Audio: a process tap (`CATapDescription` for all processes
/// except LARP itself, `AudioHardwareCreateProcessTap`) read through a private aggregate
/// device built on the default output device. `macos.AUDIO_DEVICES_CHANGED` is observed
/// with Core Audio property listeners, never by polling.
struct CoreAudioSystemDriver: SystemAudioDriver {
    func startCapture(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onChange: @escaping @Sendable () -> Void,
        drops: BufferDrops
    ) throws -> any SystemAudioRun {
        let capture = CoreAudioSystemCapture(deliver: deliver, onChange: onChange, drops: drops)
        do {
            try capture.start()
        } catch {
            capture.stop()
            throw error
        }
        return capture
    }

    func observeDevices(onChange: @escaping @Sendable () -> Void) -> any SystemAudioHandle {
        let listeners = PropertyListeners(label: "com.larp.LARP.systemTap.devices", handler: onChange)
        let system = AudioObjectID(kAudioObjectSystemObject)
        listeners.add(system, kAudioHardwarePropertyDefaultOutputDevice)
        listeners.add(system, kAudioHardwarePropertyDevices)
        return listeners
    }
}

// MARK: - Property listeners

/// Core Audio property listeners that call one handler, on a private queue (never the I/O
/// thread of Core Audio).
private final class PropertyListeners: SystemAudioHandle, @unchecked Sendable {
    let queue: DispatchQueue
    private let block: AudioObjectPropertyListenerBlock
    /// Only touched by whoever sets the listeners up and stops them, one after the other.
    private var registered: [(object: AudioObjectID, address: AudioObjectPropertyAddress)] = []

    init(label: String, handler: @escaping @Sendable () -> Void) {
        queue = DispatchQueue(label: label)
        block = { _, _ in handler() }
    }

    func add(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectAddPropertyListenerBlock(object, &address, queue, block) == noErr else { return }
        registered.append((object, address))
    }

    func stop() {
        for entry in registered {
            var address = entry.address
            AudioObjectRemovePropertyListenerBlock(entry.object, &address, queue, block)
        }
        registered.removeAll()
    }
}

// MARK: - Capture

/// One run of the capture on one output device: the tap, the aggregate device and the
/// I/O proc. It is not changed afterwards: a change of the output or of its format ends
/// it (`onChange`) and the next one is built from scratch. Every buffer is labelled with
/// the format of the tap's stream in the aggregate device, read once the aggregate
/// device has started.
private final class CoreAudioSystemCapture: SystemAudioRun, @unchecked Sendable {
    /// What the capture depends on; a listener compares it with the one of the start, so
    /// that a notification that changes nothing does not restart the capture.
    private struct Signature: Equatable {
        var defaultOutput: AudioObjectID?
        var outputRate: Float64?
        var outputIsAlive: UInt32?
        var aggregateRate: Float64?
        var subDevices: [AudioObjectID]?
        var tapRate: Float64?
        var tapChannels: UInt32?
        /// The tap's own stream among the input streams of the aggregate device.
        var tapStream: TapStreamKey?
    }

    private struct TapStreamKey: Equatable {
        var index: Int
        var streamCount: Int
        var format: StreamFormatKey
    }

    private struct TapStream {
        var object: AudioObjectID
        var index: Int
        var streamCount: Int
        var description: AudioStreamBasicDescription
    }

    private struct Devices {
        var tap: AudioObjectID
        var output: AudioObjectID
        var aggregate: AudioObjectID
    }

    private struct State {
        var devices: Devices?
        var signature: Signature?
        /// The format of the tap's stream that labels the buffers.
        var label: StreamFormatKey?
    }

    /// The label of a run, read by the I/O thread without taking a lock: it is written
    /// once, then published.
    private final class RunLabel: @unchecked Sendable {
        private let ready = Atomic<Bool>(false)
        private var format: AVAudioFormat?
        private var index = 0

        func publish(format: AVAudioFormat, index: Int) {
            self.format = format
            self.index = index
            ready.store(true, ordering: .releasing)
        }

        var value: (AVAudioFormat, Int)? {
            guard ready.load(ordering: .acquiring), let format else { return nil }
            return (format, index)
        }
    }

    /// Set when the capture ended or no longer follows the output: its buffers are
    /// dropped until the new capture takes over, so none is labelled with an old format.
    private final class Stale: Sendable {
        let value = Atomic<Bool>(false)
    }

    private let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
    private let onChange: @Sendable () -> Void
    private let drops: BufferDrops
    private let stale = Stale()
    private let state = Mutex(State())
    private let ioQueue = DispatchQueue(label: "com.larp.LARP.systemTap", qos: .userInteractive)
    private var listeners: PropertyListeners?

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let tapUUID = UUID()
    /// The format that labels the buffers of this run and the place of the tap's stream
    /// in the input list; set once the aggregate device has started.
    private let label = RunLabel()
    /// What the capture reads: set by `start()`, before the capture is handed over.
    private(set) var formats = SystemAudioFormats(reported: nil, stream: AudioFormats.storage)

    init(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void, onChange: @escaping @Sendable () -> Void,
        drops: BufferDrops
    ) {
        self.deliver = deliver
        self.onChange = onChange
        self.drops = drops
    }

    func start() throws {
        try createTap()
        let output = try Self.defaultOutputDevice()
        try createAggregateDevice(outputUID: Self.deviceUID(output))
        let devices = Devices(tap: tapID, output: output, aggregate: aggregateID)
        state.withLock { $0.devices = devices }

        // The listeners come before the aggregate device starts: a change that happens from
        // now on (Bluetooth headphones switching to their call mode) is followed.
        let listeners = PropertyListeners(label: "com.larp.LARP.systemTap.listeners") { [weak self] in
            self?.propertiesChanged()
        }
        self.listeners = listeners
        let system = AudioObjectID(kAudioObjectSystemObject)
        listeners.add(system, kAudioHardwarePropertyDefaultOutputDevice)
        listeners.add(output, kAudioDevicePropertyNominalSampleRate)
        listeners.add(output, kAudioDevicePropertyDeviceIsAlive)
        listeners.add(aggregateID, kAudioDevicePropertyNominalSampleRate)
        listeners.add(aggregateID, kAudioAggregateDevicePropertyActiveSubDeviceList)
        listeners.add(aggregateID, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        listeners.add(tapID, kAudioTapPropertyFormat)

        try startIO()

        // The format that labels every buffer is the one of the tap's stream, read now that
        // the aggregate device runs, at the rate it really runs at.
        guard var tapStream = Self.tapStream(of: aggregateID),
            let label = AVAudioFormat(streamDescription: &tapStream.description)
        else { throw SystemAudioTap.TapError(operation: "find tap stream", status: kAudio_ParamError) }
        listeners.add(tapStream.object, kAudioStreamPropertyVirtualFormat)
        formats = SystemAudioFormats(reported: readTapFormat(), stream: label)
        state.withLock {
            $0.signature = Self.signature(of: devices, tapStream: tapStream)
            $0.label = StreamFormatKey(tapStream.description)
        }
        self.label.publish(format: label, index: tapStream.index)
        // What changed while the capture was being set up is not reported by the listeners:
        // the first check compares the devices as they are now with the signature.
        listeners.queue.async { [self] in propertiesChanged() }
    }

    func stop() {
        stale.value.store(true, ordering: .sequentiallyConsistent)
        listeners?.stop()
        listeners = nil
        state.withLock { $0.devices = nil }
        if aggregateID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - Changes

    /// On a Core Audio queue. Tells once that the capture no longer follows the output.
    private func propertiesChanged() {
        let snapshot = state.withLock { state -> (Devices, Signature, StreamFormatKey)? in
            guard let devices = state.devices, let signature = state.signature, let label = state.label else { return nil }
            return (devices, signature, label)
        }
        guard let (devices, expected, label) = snapshot, !stale.value.load(ordering: .relaxed) else { return }
        let tapStream = Self.tapStream(of: devices.aggregate)
        // Something it depends on changed, or the tap's stream no longer runs in the format
        // that labels the buffers.
        let followsLabel = tapStream.map { StreamFormatKey($0.description) == label } ?? false
        guard Self.signature(of: devices, tapStream: tapStream) != expected || !followsLabel else { return }
        guard !stale.value.exchange(true, ordering: .sequentiallyConsistent) else { return }
        onChange()
    }

    /// The tap's stream and everything else the capture depends on.
    private static func signature(of devices: Devices, tapStream: TapStream?) -> Signature {
        let reported = tapFormat(devices.tap)
        return Signature(
            defaultOutput: try? defaultOutputDevice(),
            outputRate: property(devices.output, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            outputIsAlive: property(devices.output, kAudioDevicePropertyDeviceIsAlive, initial: UInt32(0)),
            aggregateRate: property(devices.aggregate, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            subDevices: objectIDs(devices.aggregate, kAudioAggregateDevicePropertyActiveSubDeviceList),
            tapRate: reported?.mSampleRate,
            tapChannels: reported?.mChannelsPerFrame,
            tapStream: tapStream.map {
                TapStreamKey(index: $0.index, streamCount: $0.streamCount, format: StreamFormatKey($0.description))
            })
    }

    // MARK: - Setup

    private func createTap() throws {
        // Every process but LARP, so that what the app plays is not recorded.
        var excluded: [NSNumber] = []
        if let own = try? Self.processObject(forPID: getpid()) {
            excluded.append(NSNumber(value: own))
        }
        let description = CATapDescription(__monoGlobalTapButExcludeProcesses: excluded)
        description.uuid = tapUUID
        description.name = "LARP system audio"
        description.muteBehavior = .unmuted
        description.isPrivate = true
        try Self.check(AudioHardwareCreateProcessTap(description, &tapID), SystemAudioTap.TapError.createTapOperation)
        // The tap exists, so the permission is granted: automatic recording can rely on it for the
        // rest of this launch of the app.
        SystemAudioGrantMemory.shared.remember()
    }

    private func createAggregateDevice(outputUID: String) throws {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "LARP system audio",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]
        try Self.check(
            AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID), "create aggregate device")
    }

    /// The format the tap reports for itself. Only informational (diagnostic log and the
    /// signature): the buffers are never labelled with it, because the tap's stream in the
    /// aggregate device can run at another rate.
    private func readTapFormat() -> AVAudioFormat? {
        guard var streamDescription = Self.tapFormat(tapID) else { return nil }
        return AVAudioFormat(streamDescription: &streamDescription)
    }

    /// Creates the I/O proc and starts the aggregate device. The buffers are dropped until
    /// the format of the tap's stream is read, which needs the aggregate device running.
    private func startIO() throws {
        try Self.check(
            AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, ioQueue) { [deliver, stale, label, drops] _, input, _, _, _ in
                guard !stale.value.load(ordering: .relaxed) else {
                    drops.record(.endedRun)
                    return
                }
                // Before the format of the tap's stream is read nothing is known about the buffer:
                // it is not counted as unreadable, which is for a stream that cannot be read.
                guard let (format, index) = label.value else { return }
                let read = TapInputStreams.withBuffer(in: input, at: index, format: format) { buffer in
                    deliver(buffer, ProcessInfo.processInfo.systemUptime)
                }
                if !read { drops.record(.unreadable) }
            }, "create IO proc")
        try Self.check(AudioDeviceStart(aggregateID, ioProcID), "start aggregate device")
    }

    /// The tap's own stream among the input streams of the aggregate device: it comes after
    /// the input streams of the sub-devices (a headset in its call mode adds its microphone
    /// there), so it is found by its place, never as the first one.
    private static func tapStream(of aggregate: AudioObjectID) -> TapStream? {
        guard let streams = objectIDs(aggregate, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput),
            let subDevices = objectIDs(aggregate, kAudioAggregateDevicePropertyActiveSubDeviceList)
        else { return nil }
        let subDeviceStreams = subDevices.reduce(0) {
            $0 + (objectIDs($1, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)?.count ?? 0)
        }
        guard let index = TapInputStreams.index(subDeviceInputStreams: subDeviceStreams, inputStreams: streams.count),
            let description = property(streams[index], kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
        else { return nil }
        return TapStream(object: streams[index], index: index, streamCount: streams.count, description: description)
    }

    // MARK: - Core Audio helpers

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw SystemAudioTap.TapError(operation: operation, status: status) }
    }

    private static func globalAddress(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// A fixed-size property, or `nil` when the object does not answer (it is gone).
    private static func property<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) -> T? {
        var address = globalAddress(selector)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func objectIDs(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID]? {
        var address = globalAddress(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        var ids = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return nil }
        return ids
    }

    private static func tapFormat(_ tap: AudioObjectID) -> AudioStreamBasicDescription? {
        property(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
    }

    private static func processObject(forPID pid: pid_t) throws -> AudioObjectID {
        var address = globalAddress(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object),
            "translate PID")
        return object
    }

    private static func defaultOutputDevice() throws -> AudioObjectID {
        guard
            let device = property(
                AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice,
                initial: AudioObjectID(kAudioObjectUnknown)), device != kAudioObjectUnknown
        else { throw SystemAudioTap.TapError(operation: "default output device", status: kAudio_ParamError) }
        return device
    }

    private static func deviceUID(_ device: AudioObjectID) throws -> String {
        var address = globalAddress(kAudioDevicePropertyDeviceUID)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid), "output device UID")
        guard let uid else { throw SystemAudioTap.TapError(operation: "output device UID", status: kAudio_ParamError) }
        return uid.takeRetainedValue() as String
    }
}

// MARK: - The tap's stream in the aggregate device

/// The part of a stream format that tells whether audio is read as it arrives.
private struct StreamFormatKey: Equatable {
    var sampleRate: Float64
    var channels: UInt32
    var formatID: AudioFormatID
    var formatFlags: AudioFormatFlags
    var bitsPerChannel: UInt32

    init(_ description: AudioStreamBasicDescription) {
        sampleRate = description.mSampleRate
        channels = description.mChannelsPerFrame
        formatID = description.mFormatID
        formatFlags = description.mFormatFlags
        bitsPerChannel = description.mBitsPerChannel
    }
}

/// The input list of the aggregate device holds one buffer per input stream: first the
/// streams of its sub-devices (a headset in its call mode adds its own microphone stream
/// there), then the stream of the tap.
enum TapInputStreams {
    /// The place of the tap's stream among `inputStreams` input streams, of which
    /// `subDeviceInputStreams` belong to the sub-devices; `nil` when none is left for the
    /// tap, which then cannot be found.
    static func index(subDeviceInputStreams: Int, inputStreams: Int) -> Int? {
        let index = inputStreams - 1
        return index >= subDeviceInputStreams && index >= 0 ? index : nil
    }

    /// Calls `body` with the buffer at `index` of `list` as a buffer in `format`, valid
    /// only during the call, and no other buffer of the list; `false` (and `body` not
    /// called) when the list has no such buffer or it cannot be read in `format`.
    @discardableResult
    static func withBuffer(
        in list: UnsafePointer<AudioBufferList>, at index: Int, format: AVAudioFormat, _ body: (AVAudioPCMBuffer) -> Void
    ) -> Bool {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        guard index >= 0, index < buffers.count else { return false }
        var single = AudioBufferList(mNumberBuffers: 1, mBuffers: buffers[index])
        return withUnsafePointer(to: &single) { pointer in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: pointer, deallocator: nil) else {
                return false
            }
            body(buffer)
            return true
        }
    }
}
