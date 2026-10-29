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
        onChange: @escaping @Sendable () -> Void
    ) throws -> any SystemAudioHandle {
        let capture = CoreAudioSystemCapture(deliver: deliver, onChange: onChange)
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

    func add(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
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
/// I/O proc, with the format of the tap read once for all its buffers. It is not
/// changed afterwards: a change of the output or of its format ends it (`onChange`) and
/// the next one is built from scratch.
private final class CoreAudioSystemCapture: SystemAudioHandle, @unchecked Sendable {
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
    }

    private struct Devices {
        var tap: AudioObjectID
        var output: AudioObjectID
        var aggregate: AudioObjectID
    }

    private struct State {
        var devices: Devices?
        var signature: Signature?
    }

    /// Set when the capture ended or no longer follows the output: its buffers are
    /// dropped until the new capture takes over, so none is labelled with an old format.
    private final class Stale: Sendable {
        let value = Atomic<Bool>(false)
    }

    private let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
    private let onChange: @Sendable () -> Void
    private let stale = Stale()
    private let state = Mutex(State())
    private let ioQueue = DispatchQueue(label: "com.larp.LARP.systemTap", qos: .userInteractive)
    private var listeners: PropertyListeners?

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let tapUUID = UUID()

    init(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void, onChange: @escaping @Sendable () -> Void
    ) {
        self.deliver = deliver
        self.onChange = onChange
    }

    func start() throws {
        try createTap()
        let output = try Self.defaultOutputDevice()
        try createAggregateDevice(outputUID: Self.deviceUID(output))
        state.withLock { $0.devices = Devices(tap: tapID, output: output, aggregate: aggregateID) }

        // The listeners come before the format is read: a change that happens from now on
        // (Bluetooth headphones switching to their call mode) is followed.
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
        listeners.add(tapID, kAudioTapPropertyFormat)

        let format = try readTapFormat()
        state.withLock { $0.signature = Self.signature(of: Devices(tap: tapID, output: output, aggregate: aggregateID)) }
        try startIO(format: format)
        // What changed between the first listener and the signature is not reported.
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
        let snapshot = state.withLock { state -> (Devices, Signature)? in
            guard let devices = state.devices, let signature = state.signature else { return nil }
            return (devices, signature)
        }
        guard let (devices, expected) = snapshot, !stale.value.load(ordering: .relaxed) else { return }
        guard Self.signature(of: devices) != expected else { return }
        guard !stale.value.exchange(true, ordering: .sequentiallyConsistent) else { return }
        onChange()
    }

    private static func signature(of devices: Devices) -> Signature {
        Signature(
            defaultOutput: try? defaultOutputDevice(),
            outputRate: property(devices.output, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            outputIsAlive: property(devices.output, kAudioDevicePropertyDeviceIsAlive, initial: UInt32(0)),
            aggregateRate: property(devices.aggregate, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            subDevices: objectIDs(devices.aggregate, kAudioAggregateDevicePropertyActiveSubDeviceList),
            tapRate: tapFormat(devices.tap)?.mSampleRate,
            tapChannels: tapFormat(devices.tap)?.mChannelsPerFrame)
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

    private func readTapFormat() throws -> AVAudioFormat {
        guard var streamDescription = Self.tapFormat(tapID) else {
            throw SystemAudioTap.TapError(operation: "read tap format", status: kAudio_ParamError)
        }
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw SystemAudioTap.TapError(operation: "tap format", status: kAudio_ParamError)
        }
        return format
    }

    /// Every buffer is labelled with `format`, the one of the tap read for this run.
    private func startIO(format: AVAudioFormat) throws {
        try Self.check(
            AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, ioQueue) { [deliver, stale] _, input, _, _, _ in
                guard !stale.value.load(ordering: .relaxed),
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil)
                else { return }
                deliver(buffer, ProcessInfo.processInfo.systemUptime)
            }, "create IO proc")
        try Self.check(AudioDeviceStart(aggregateID, ioProcID), "start aggregate device")
    }

    // MARK: - Core Audio helpers

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw SystemAudioTap.TapError(operation: operation, status: status) }
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    /// A fixed-size property, or `nil` when the object does not answer (it is gone).
    private static func property<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) -> T? {
        var address = globalAddress(selector)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func objectIDs(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID]? {
        var address = globalAddress(selector)
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
