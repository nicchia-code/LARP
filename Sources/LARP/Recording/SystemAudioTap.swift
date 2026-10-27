import AVFoundation
import CoreAudio
import Foundation

/// Captures everything the Mac plays except LARP itself, with a Core Audio process
/// tap (`CATapDescription`) read through a private aggregate device, and feeds a
/// `TrackPipeline`. Needs only the system audio recording permission, not the
/// screen recording one.
final class SystemAudioTap: @unchecked Sendable {
    struct TapError: LocalizedError, CustomStringConvertible {
        let operation: String
        let status: OSStatus
        var description: String { "\(operation) failed (OSStatus \(status))" }
        var errorDescription: String? {
            "Impossibile catturare l'audio di sistema (\(operation), errore \(status)). "
                + "Controllare il permesso «Registrazione audio di sistema» in Impostazioni di Sistema."
        }
    }

    private let pipeline: TrackPipeline
    private let queue = DispatchQueue(label: "com.larp.LARP.systemTap", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(pipeline: TrackPipeline) {
        self.pipeline = pipeline
    }

    func start() throws {
        do {
            try createTap()
            try createAggregateDevice()
            try startIO()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
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

    // MARK: - Setup

    private var tapUUID = UUID()

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
        try Self.check(AudioHardwareCreateProcessTap(description, &tapID), "create process tap")
    }

    private func createAggregateDevice() throws {
        let outputUID = try Self.defaultOutputDeviceUID()
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

    private func startIO() throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var streamDescription = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try Self.check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &streamDescription), "read tap format")
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw TapError(operation: "tap format", status: kAudio_ParamError)
        }

        try Self.check(
            AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { [pipeline] _, input, _, _, _ in
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) else {
                    return
                }
                pipeline.ingest(borrowing: buffer)
            }, "create IO proc")
        try Self.check(AudioDeviceStart(aggregateID, ioProcID), "start aggregate device")
    }

    // MARK: - Core Audio helpers

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw TapError(operation: operation, status: status) }
    }

    private static func processObject(forPID pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object),
            "translate PID")
        return object
    }

    private static func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device),
            "default output device")

        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid), "output device UID")
        guard let uid else { throw TapError(operation: "output device UID", status: kAudio_ParamError) }
        return uid.takeRetainedValue() as String
    }
}
