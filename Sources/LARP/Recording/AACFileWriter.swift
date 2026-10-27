import AVFoundation
import AudioToolbox
import Foundation

/// Writes mono audio at `AudioFormats.storageSampleRate` to a CAF file as AAC at
/// about 32 kbps, in chunks, so a file cut by a crash or a power loss can still be
/// read up to the last `flush()`.
///
/// `AVAudioFile` keeps the packet table of an AAC file in memory until it is
/// closed, so a file that is not closed cannot be read at all. `ExtAudioFile`
/// plus `AudioFileOptimize` writes the table out on demand.
///
/// Not thread-safe: use from one queue.
final class AACFileWriter {
    struct WriteError: LocalizedError, CustomStringConvertible {
        let operation: String
        let status: OSStatus
        var description: String { "\(operation) failed (OSStatus \(status))" }
        var errorDescription: String? {
            "Impossibile salvare l'audio su disco (\(operation), errore \(status))."
        }
    }

    /// Seconds of audio written between two flushes: a crash loses at most this much.
    static let flushInterval: TimeInterval = 2

    private var file: ExtAudioFileRef?
    private var audioFile: AudioFileID?
    private(set) var framesWritten: Int64 = 0
    private var framesSinceFlush: Int64 = 0

    init(url: URL) throws {
        try? FileManager.default.removeItem(at: url)

        let rate = AudioFormats.storageSampleRate
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: rate, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: 0,
            mBytesPerPacket: 0, mFramesPerPacket: 1024, mBytesPerFrame: 0,
            mChannelsPerFrame: 1, mBitsPerChannel: 0, mReserved: 0)
        var created: ExtAudioFileRef?
        try Self.check(
            ExtAudioFileCreateWithURL(
                url as CFURL, kAudioFileCAFType, &fileFormat, nil, AudioFileFlags.eraseFile.rawValue, &created),
            "create \(url.lastPathComponent)")
        guard let created else { throw WriteError(operation: "create", status: kAudio_ParamError) }
        file = created

        do {
            // Mono, so the interleaved and non-interleaved layouts of the buffers are the same.
            var clientFormat = AudioStreamBasicDescription(
                mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
                mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
            try Self.check(
                ExtAudioFileSetProperty(
                    created, kExtAudioFileProperty_ClientDataFormat,
                    UInt32(MemoryLayout.size(ofValue: clientFormat)), &clientFormat),
                "set client format")

            var converter: AudioConverterRef?
            var size = UInt32(MemoryLayout<AudioConverterRef?>.size)
            try Self.check(
                ExtAudioFileGetProperty(created, kExtAudioFileProperty_AudioConverter, &size, &converter),
                "get converter")
            var bitRate = UInt32(AudioFormats.storageBitRate)
            try Self.check(
                AudioConverterSetProperty(converter!, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &bitRate),
                "set bit rate")
            // Makes the file pick up the new converter settings.
            var noConfig: CFArray?
            try Self.check(
                ExtAudioFileSetProperty(
                    created, kExtAudioFileProperty_ConverterConfig, UInt32(MemoryLayout<CFArray?>.size), &noConfig),
                "apply converter config")

            var underlying: AudioFileID?
            size = UInt32(MemoryLayout<AudioFileID?>.size)
            try Self.check(
                ExtAudioFileGetProperty(created, kExtAudioFileProperty_AudioFile, &size, &underlying),
                "get audio file")
            audioFile = underlying
        } catch {
            ExtAudioFileDispose(created)
            file = nil
            throw error
        }
    }

    deinit {
        close()
    }

    /// Appends `buffer`, which must be in `AudioFormats.storage`. Flushes to disk
    /// every `flushInterval` seconds of audio.
    func write(_ buffer: AVAudioPCMBuffer) throws {
        guard let file, buffer.frameLength > 0 else { return }
        try Self.check(ExtAudioFileWrite(file, buffer.frameLength, buffer.audioBufferList), "write")
        framesWritten += Int64(buffer.frameLength)
        framesSinceFlush += Int64(buffer.frameLength)
        if Double(framesSinceFlush) >= Self.flushInterval * AudioFormats.storageSampleRate {
            flush()
        }
    }

    /// Writes the packet table, making everything written so far readable even if
    /// the file is never closed.
    func flush() {
        guard let audioFile else { return }
        AudioFileOptimize(audioFile)
        framesSinceFlush = 0
    }

    /// Finishes the file.
    func close() {
        guard let file else { return }
        ExtAudioFileDispose(file)
        self.file = nil
        audioFile = nil
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw WriteError(operation: operation, status: status) }
    }
}
