import AVFoundation
import Dispatch
import Foundation
import os

/// Where a capture hands the audio it captures. Called from an audio thread.
protocol AudioInput: Sendable {
    /// Takes the audio of `buffer`, which the caller may reuse as soon as this returns.
    /// `arrival` is the system uptime at which the last frame of `buffer` was captured.
    func ingest(borrowing buffer: AVAudioPCMBuffer, arrival: TimeInterval)
}

extension AudioInput {
    /// `ingest(borrowing:arrival:)` for a buffer that has just been captured.
    func ingest(borrowing buffer: AVAudioPCMBuffer) {
        ingest(borrowing: buffer, arrival: ProcessInfo.processInfo.systemUptime)
    }
}

/// One track of a recording: takes the audio as the device delivers it, converts it
/// to `AudioFormats.storage`, writes it to the track's file and only then hands it to
/// the sink. Capture callbacks only copy the buffer and return: conversion, disk
/// writes and the sink run on a private serial queue, so they never block the
/// audio threads.
final class TrackPipeline: AudioInput, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "capture")
    /// Missing audio shorter than this is not filled with silence.
    private static let gapTolerance: TimeInterval = 1
    /// Longest piece of silence written at once.
    private static let silenceChunk: TimeInterval = 10

    let track: AudioTrack
    private let queue: DispatchQueue
    private let sink: (any AudioBufferSink)?

    // Everything below is confined to `queue`.
    private let writer: AACFileWriter
    private let converter = BufferConverter(target: AudioFormats.storage)
    private var startUptime: TimeInterval?
    private var failed = false
    /// When the pipeline was made: the start of the track while no audio has arrived yet.
    private let createdUptime = ProcessInfo.processInfo.systemUptime

    init(track: AudioTrack, folder: URL, sink: (any AudioBufferSink)?) throws {
        self.track = track
        self.sink = sink
        queue = DispatchQueue(label: "com.larp.LARP.capture.\(track.fileName)", qos: .userInitiated)
        writer = try AACFileWriter(url: track.fileURL(in: folder))
    }

    /// Called from an audio thread. The buffer is copied: the caller may reuse it
    /// as soon as this returns.
    func ingest(borrowing buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard let copy = buffer.copy() else { return }
        enqueue(copy, arrival: arrival)
    }

    /// Takes `buffer`, which the caller does not touch again.
    func enqueue(_ buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        let chunk = AudioChunk(buffer: buffer)
        queue.async { [self] in
            process(chunk.buffer, arrival: arrival)
        }
    }

    /// Waits for everything ingested so far to be written and handed to the sink,
    /// then closes the file.
    ///
    /// `silenceUntil` is the uptime the track must reach: what is missing up to it is
    /// filled with silence first, so that the track is as long as the recording even
    /// when its audio stopped arriving (the microphone was lost). `nil` leaves the
    /// track as it is, for instance an empty one.
    func finish(silenceUntil end: TimeInterval? = nil) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if let end, !failed { fillSilence(until: end) }
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
            if expected - written > Self.gapTolerance {
                try writeSilence(seconds: expected - written)
            }
            try writer.write(converted)
            sink?.consume(AudioChunk(buffer: converted), track: track)
        } catch {
            failed = true
            Self.logger.error("Capture of \(self.track.fileName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fills what is missing up to `end` with silence, whatever its length.
    private func fillSilence(until end: TimeInterval) {
        let missing = end - (startUptime ?? createdUptime) - Double(writer.framesWritten) / AudioFormats.storageSampleRate
        guard missing > 0 else { return }
        do {
            try writeSilence(seconds: missing)
        } catch {
            failed = true
            Self.logger.error("Capture of \(self.track.fileName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Writes silence in pieces of at most `silenceChunk`, so that a long gap does not
    /// need one huge buffer.
    private func writeSilence(seconds: TimeInterval) throws {
        var remaining = seconds
        while remaining > 0 {
            let piece = min(remaining, Self.silenceChunk)
            guard let silence = Self.silence(seconds: piece) else { return }
            try writer.write(silence)
            sink?.consume(AudioChunk(buffer: silence), track: track)
            remaining -= piece
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
