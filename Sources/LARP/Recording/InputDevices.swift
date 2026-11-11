import CoreAudio
import Foundation

/// An audio input device as Core Audio reports it.
struct InputDevice: Equatable, Hashable, Sendable {
    /// The unique identifier Core Audio gives the device: it is the same every time the device is
    /// connected, unlike its `id`.
    let uid: String
    let name: String
    /// The Core Audio object of the device while it is connected.
    let id: AudioDeviceID
}

/// What the app asks Core Audio about the input devices; replaced in tests by fake devices.
protocol InputDevices: Sendable {
    /// The input devices connected now, in the order Core Audio lists them.
    func connected() -> [InputDevice]

    /// The default input device of the Mac, `nil` when there is none.
    func systemDefault() -> InputDevice?

    /// Calls `handler`, from a private queue, whenever the connected devices or the default input
    /// device change, until the returned observation is cancelled.
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation
}

extension InputDevices {
    /// The microphone to use: the chosen input device when it is among the connected ones, matched
    /// by its unique identifier, otherwise the default input device. With no choice (`nil`,
    /// "Predefinito di sistema") always the default one.
    func microphoneToUse(chosenUID: String?) -> InputDevice? {
        if let chosenUID, let device = connected().first(where: { $0.uid == chosenUID }) {
            return device
        }
        return systemDefault()
    }
}

protocol InputDevicesObservation: Sendable {
    func cancel()
}

/// `InputDevices` on Core Audio.
struct CoreAudioInputDevices: InputDevices {
    private static let queue = DispatchQueue(label: "com.larp.LARP.input-devices")

    private static let changeAddresses = [
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain),
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain),
    ]

    func connected() -> [InputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap(Self.inputDevice)
    }

    func systemDefault() -> InputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
            id != AudioDeviceID(kAudioObjectUnknown)
        else { return nil }
        return Self.inputDevice(id)
    }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any InputDevicesObservation {
        let listener: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        for var address in Self.changeAddresses {
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, Self.queue, listener)
        }
        return Observation(listener: listener)
    }

    /// The device `id` as an input device; `nil` when it has no input channel or cannot be read.
    private static func inputDevice(_ id: AudioDeviceID) -> InputDevice? {
        guard hasInput(id), let uid = string(kAudioDevicePropertyDeviceUID, of: id) else { return nil }
        return InputDevice(uid: uid, name: string(kAudioObjectPropertyName, of: id) ?? uid, id: id)
    }

    private static func hasInput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        let buffers = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffers.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffers) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(buffers.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private final class Observation: InputDevicesObservation, @unchecked Sendable {
        private let listener: AudioObjectPropertyListenerBlock

        init(listener: @escaping AudioObjectPropertyListenerBlock) {
            self.listener = listener
        }

        func cancel() {
            for var address in CoreAudioInputDevices.changeAddresses {
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject), &address, CoreAudioInputDevices.queue, listener)
            }
        }
    }
}
