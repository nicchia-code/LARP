import CoreAudio
import Foundation

/// Reading Core Audio properties.
enum CoreAudioProperty {
    static func address(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// A fixed-size property, or `nil` when the object does not answer (it is gone).
    static func value<T>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, initial: T
    ) -> T? {
        var address = address(selector, scope: scope)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    /// A list of objects, or `nil` when the object does not answer.
    static func objectIDs(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID]? {
        var address = address(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        var ids = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return nil }
        return ids
    }

    /// The default input or output device (`kAudioHardwarePropertyDefaultInputDevice`,
    /// `kAudioHardwarePropertyDefaultOutputDevice`), `nil` when there is none.
    static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        guard
            let device = value(
                AudioObjectID(kAudioObjectSystemObject), selector, initial: AudioDeviceID(kAudioObjectUnknown)),
            device != AudioDeviceID(kAudioObjectUnknown)
        else { return nil }
        return device
    }
}

/// An observation made of Core Audio listeners, cancelled by removing them.
final class ListenerObservation: InputDevicesObservation, @unchecked Sendable {
    private let listeners: PropertyListeners

    init(_ listeners: PropertyListeners) {
        self.listeners = listeners
    }

    func cancel() { listeners.stop() }
}
