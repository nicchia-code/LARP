import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

/// What changed under a running `MicrophoneUnit`.
enum MicrophoneUnitChange: Sendable {
    /// The microphone in use delivers another format (sample rate, stream format).
    case formatChanged
    /// The microphone in use is gone (the device is not alive any more or has no input).
    case gone
}

/// What `MicrophoneCapture` needs from the input of the microphone to use; replaced in tests by
/// fake devices.
///
/// A unit is used for one start only: `MicrophoneCapture` makes a new one at every start and
/// restart, so the format it reads is the one the microphone delivers now.
protocol MicrophoneUnit: AnyObject, Sendable {
    /// Whether macOS voice processing is on for the input: never, but tests check it.
    var isVoiceProcessingEnabled: Bool { get }

    /// The format the input side of the device delivers now; `nil` when there is no microphone
    /// (no device, a sample rate of zero or no channels).
    func inputFormat() -> AVAudioFormat?

    /// Starts delivering the input, in `format`, to `deliver`, with the system uptime at which
    /// the last frame of the buffer was captured; the buffer is only valid during the call, and
    /// `deliver` is called from the audio thread.
    func start(format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) throws

    /// Stops the input. Safe to call on a unit that did not start, and with the lock of the
    /// microphone held.
    func stop()

    /// Follows the sample rate, the stream format and the liveness of the device in use, from a
    /// private queue, until the observation is cancelled: `handler` is called only when the
    /// format of the microphone differs from the one of the start, or the microphone is gone.
    /// Called after `start`; the observation is cancelled outside the lock of the microphone.
    func observeChanges(_ handler: @escaping @Sendable (MicrophoneUnitChange) -> Void) -> any InputDevicesObservation
}

/// `MicrophoneUnit` on Core Audio, input only: an audio unit `kAudioUnitSubType_HALOutput` with
/// input enabled and output disabled, its current device set to the microphone to use (the
/// chosen input device, `nil` for the default one). macOS voice processing is never enabled, and
/// the output side of the machine is never opened, so a change of the output never stops it.
final class HALMicrophoneUnit: MicrophoneUnit, @unchecked Sendable {
    struct CoreAudioError: LocalizedError {
        let operation: String
        let status: OSStatus
        var errorDescription: String? { "\(operation) failed (OSStatus \(status))" }
    }

    /// What the input callback reads, on the audio thread, without a lock: written before the unit
    /// starts, read-only after.
    fileprivate final class RenderContext: @unchecked Sendable {
        var unit: AudioUnit?
        let buffer: AVAudioPCMBuffer
        let sampleRate: Double
        let deliver: @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void

        init(buffer: AVAudioPCMBuffer, sampleRate: Double, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) {
            self.buffer = buffer
            self.sampleRate = sampleRate
            self.deliver = deliver
        }
    }

    /// The part of a stream format that tells whether the audio is read as it arrives.
    private struct FormatKey: Equatable {
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

    /// What the capture depends on; a listener compares it with the one of the start, so that a
    /// notification that changes nothing does not restart the capture.
    private struct Signature: Equatable {
        var sampleRate: Float64?
        var isAlive: UInt32?
        var format: FormatKey?
        var streamFormats: [FormatKey?]?

        /// `true` when the microphone cannot deliver any more.
        var isGone: Bool {
            guard isAlive == 1, let format else { return true }
            return format.sampleRate <= 0 || format.channels == 0
        }
    }

    /// The device to read, `nil` for the default input device.
    private let device: InputDevice?
    private var audioUnit: AudioUnit?
    private var context: RenderContext?
    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var startSignature: Signature?

    init(device: InputDevice? = nil) {
        self.device = device
    }

    var isVoiceProcessingEnabled: Bool { false }

    func inputFormat() -> AVAudioFormat? {
        guard let id = resolvedDevice(), let description = Self.inputDescription(of: id), description.mSampleRate > 0,
            description.mChannelsPerFrame > 0
        else { return nil }
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: description.mSampleRate, channels: description.mChannelsPerFrame,
            interleaved: false)
    }

    func start(format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void) throws {
        guard let id = resolvedDevice() else { throw Self.error("find input device", kAudio_ParamError) }
        deviceID = id
        do {
            try configureAndStart(format: format, deliver: deliver)
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let audioUnit {
            // Returns when the input callback has finished.
            AudioOutputUnitStop(audioUnit)
            AudioUnitUninitialize(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
        }
        audioUnit = nil
        context = nil
    }

    func observeChanges(_ handler: @escaping @Sendable (MicrophoneUnitChange) -> Void) -> any InputDevicesObservation {
        let id = deviceID
        let expected = startSignature
        let check: @Sendable () -> Void = {
            let current = Self.signature(of: id)
            if current.isGone {
                handler(.gone)
            } else if current != expected {
                handler(.formatChanged)
            }
        }
        let listeners = PropertyListeners(label: "com.larp.LARP.microphone.device", handler: check)
        listeners.add(id, kAudioDevicePropertyNominalSampleRate)
        listeners.add(id, kAudioDevicePropertyDeviceIsAlive)
        listeners.add(id, kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput)
        listeners.add(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        for stream in CoreAudioProperty.objectIDs(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput) ?? [] {
            listeners.add(stream, kAudioStreamPropertyVirtualFormat)
        }
        // What changed while the capture was being set up is not reported by the listeners.
        listeners.queue.async(execute: check)
        return ListenerObservation(listeners)
    }

    // MARK: - Setup

    private func configureAndStart(
        format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void
    ) throws {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw Self.error("find HAL output unit", kAudioUnitErr_InvalidProperty)
        }
        var created: AudioUnit?
        try Self.check(AudioComponentInstanceNew(component, &created), "create HAL output unit")
        guard let unit = created else { throw Self.error("create HAL output unit", kAudio_ParamError) }
        audioUnit = unit

        // Input enabled (bus 1), output disabled (bus 0), on the device to read.
        try Self.set(unit, kAudioOutputUnitProperty_EnableIO, scope: kAudioUnitScope_Input, element: 1, UInt32(1))
        try Self.set(unit, kAudioOutputUnitProperty_EnableIO, scope: kAudioUnitScope_Output, element: 0, UInt32(0))
        try Self.set(unit, kAudioOutputUnitProperty_CurrentDevice, scope: kAudioUnitScope_Global, element: 0, deviceID)
        // What the unit hands over: the format of the device as float, non-interleaved.
        try Self.set(
            unit, kAudioUnitProperty_StreamFormat, scope: kAudioUnitScope_Output, element: 1, format.streamDescription.pointee)

        // The buffer the callback renders into, prepared before the unit runs.
        var maximumFrames = UInt32(4096)
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioUnitGetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, &size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(maximumFrames, 4096)) else {
            throw Self.error("prepare buffer", kAudio_MemFullError)
        }
        let context = RenderContext(buffer: buffer, sampleRate: format.sampleRate, deliver: deliver)
        context.unit = unit
        self.context = context
        let callback = AURenderCallbackStruct(
            inputProc: microphoneInputCallback, inputProcRefCon: Unmanaged.passUnretained(context).toOpaque())
        try Self.set(unit, kAudioOutputUnitProperty_SetInputCallback, scope: kAudioUnitScope_Global, element: 0, callback)

        try Self.check(AudioUnitInitialize(unit), "initialize HAL output unit")
        startSignature = Self.signature(of: deviceID)
        try Self.check(AudioOutputUnitStart(unit), "start HAL output unit")
    }

    /// The device to read: the chosen one, otherwise the default input device.
    private func resolvedDevice() -> AudioDeviceID? {
        if let device { return device.id }
        return CoreAudioProperty.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
    }

    // MARK: - Reading the device

    /// The format of the input side of the device.
    private static func inputDescription(of device: AudioDeviceID) -> AudioStreamBasicDescription? {
        CoreAudioProperty.value(
            device, kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput, initial: AudioStreamBasicDescription())
    }

    private static func signature(of device: AudioDeviceID) -> Signature {
        let streams = CoreAudioProperty.objectIDs(device, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        return Signature(
            sampleRate: CoreAudioProperty.value(device, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            isAlive: CoreAudioProperty.value(device, kAudioDevicePropertyDeviceIsAlive, initial: UInt32(0)),
            format: inputDescription(of: device).map(FormatKey.init),
            streamFormats: streams.map { streams in
                streams.map {
                    CoreAudioProperty.value($0, kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
                        .map(FormatKey.init)
                }
            })
    }

    // MARK: - Helpers

    private static func error(_ operation: String, _ status: OSStatus) -> CoreAudioError {
        CoreAudioError(operation: operation, status: status)
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw error(operation, status) }
    }

    private static func set<T>(
        _ unit: AudioUnit, _ property: AudioUnitPropertyID, scope: AudioUnitScope, element: AudioUnitElement, _ value: T
    ) throws {
        var value = value
        try check(
            AudioUnitSetProperty(unit, property, scope, element, &value, UInt32(MemoryLayout<T>.size)),
            "set audio unit property \(property)")
    }
}

/// The input callback of the HAL unit, on the audio thread: it renders into the buffer prepared in
/// advance and hands it over. No lock, allocation or log.
private let microphoneInputCallback: AURenderCallback = { refCon, flags, timeStamp, bus, frames, _ in
    let context = Unmanaged<HALMicrophoneUnit.RenderContext>.fromOpaque(refCon).takeUnretainedValue()
    guard let unit = context.unit, frames <= context.buffer.frameCapacity else { return kAudio_ParamError }
    // The frame length sets the size of every channel's data, which the render fills.
    context.buffer.frameLength = frames
    let status = AudioUnitRender(unit, flags, timeStamp, bus, frames, context.buffer.mutableAudioBufferList)
    guard status == noErr else { return status }
    // The system uptime of the last frame: the host time of the first one plus the length.
    let uptime: TimeInterval
    if timeStamp.pointee.mFlags.contains(.hostTimeValid) {
        uptime = Double(AudioConvertHostTimeToNanos(timeStamp.pointee.mHostTime)) / 1_000_000_000
    } else {
        uptime = ProcessInfo.processInfo.systemUptime
    }
    context.deliver(context.buffer, uptime + Double(frames) / context.sampleRate)
    return noErr
}
