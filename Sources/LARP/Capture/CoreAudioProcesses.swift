import CoreAudio
import Foundation

/// Thin reading helpers over the Core Audio process objects (macOS 14.2+).
enum CoreAudioProcesses {
    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static var processListAddress: AudioObjectPropertyAddress {
        address(kAudioHardwarePropertyProcessObjectList)
    }

    static var isRunningInputAddress: AudioObjectPropertyAddress {
        address(kAudioProcessPropertyIsRunningInput)
    }

    /// Every process object known to Core Audio.
    static func processObjects() -> [AudioObjectID] {
        var address = processListAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0
        else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr
        else { return [] }
        return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    static func isRunningInput(_ process: AudioObjectID) -> Bool {
        var address = isRunningInputAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    static func bundleIdentifier(of process: AudioObjectID) -> String? {
        var address = address(kAudioProcessPropertyBundleID)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    static func pid(of process: AudioObjectID) -> pid_t? {
        var address = address(kAudioProcessPropertyPID)
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    /// The process object of a process, if Core Audio knows it.
    static func processObject(forPID pid: pid_t) -> AudioObjectID? {
        var address = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var qualifier = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<pid_t>.size), &qualifier, &size, &object
        )
        guard status == noErr, object != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return object
    }
}
