import AVFoundation
import Dispatch
import Foundation
import os

/// One track of a recording: takes the audio as the device delivers it, converts it
/// to `AudioFormats.storage`, writes it to the track's file and only then hands it to
/// the sink. Capture callbacks only copy the buffer and return: conversion, disk
/// writes and the sink run on a private serial queue, so they never block the
/// audio threads.
final class TrackPipeline: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "capture")
    /// Missing audio shorter than this is not filled with silence.
    private static let gapTolerance: TimeInterval = 1

    let track: AudioTrack
    private let queue: DispatchQueue
    private let sink: (any AudioBufferSink)?

    // Everything below is confined to `queue`.
    private let writer: AACFileWriter
    private let converter = BufferConverter(target: AudioFormats.storage)
    private var startUptime: TimeInterval?
    private var failed = false

    init(track: AudioTrack, folder: URL, sink: (any AudioBufferSink)?) throws {
        self.track = track
        self.sink = sink
        queue = DispatchQueue(label: "com.larp.LARP.capture.\(track.fileName)", qos: .userInitiated)
        writer = try AACFileWriter(url: track.fileURL(in: folder))
    }

    /// Called from an audio thread. The buffer is copied: the caller may reuse it
    /// as soon as this returns.
    func ingest(borrowing buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.copy() else { return }
        let arrival = ProcessInfo.processInfo.systemUptime
        let chunk = AudioChunk(buffer: copy)
        queue.async { [self] in
            process(chunk.buffer, arrival: arrival)
        }
    }

    /// Waits for everything ingested so far to be written and handed to the sink,
    /// then closes the file.
    func finish() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                writer.close()
                continuation.resume()
            }
        }
    }

    // MARK: - On the queue

    private func process(_ input: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard !failed else { return }
        let rate = AudioFormats.storageSampleRate
        if startUptime == nil {
            startUptime = arrival - Double(input.frameLength) / input.format.sampleRate
        }
        do {
            let converted = try converter.convert(input)
            // A gap in the capture (for instance while the input device changed)
            // would shift every later time: fill it with silence.
            let expected = arrival - (startUptime ?? arrival)
            let written = Double(writer.framesWritten + Int64(converted.frameLength)) / rate
            if expected - written > Self.gapTolerance, let silence = Self.silence(seconds: expected - written) {
                try writer.write(silence)
                sink?.consume(AudioChunk(buffer: silence), track: track)
            }
            try writer.write(converted)
            sink?.consume(AudioChunk(buffer: converted), track: track)
        } catch {
            failed = true
            Self.logger.error("Capture of \(self.track.fileName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func silence(seconds: TimeInterval) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * AudioFormats.storageSampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        if let data = buffer.floatChannelData {
            data[0].update(repeating: 0, count: Int(frames))
        }
        return buffer
    }
}

extension AVAudioPCMBuffer {
    /// A deep copy of the audio, or `nil` if the buffer cannot be allocated.
    func copy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            guard let fromData = from.mData, let toData = to.mData else { continue }
            memcpy(toData, fromData, min(Int(from.mDataByteSize), Int(to.mDataByteSize)))
        }
        return copy
    }
}
