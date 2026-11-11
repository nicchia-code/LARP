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
    private static let logger = CaptureLog.logger
    /// Missing audio shorter than this is not filled with silence.
    private static let gapTolerance: TimeInterval = 1
    /// Longest piece of silence written at once.
    private static let silenceChunk: TimeInterval = 10

    let track: AudioTrack
    /// The system uptime at which the track starts: the start of the recording, when its
    /// file is created. Audio that is missing before the first piece that arrives is
    /// filled with silence like any other gap.
    let startUptime: TimeInterval
    /// The buffers of the source of this track that were dropped, and why.
    let drops = BufferDrops()
    private let queue: DispatchQueue
    private let sink: (any AudioBufferSink)?
    private let levels: (@Sendable (AudioTrack, TrackLevel) -> Void)?

    // Everything below is confined to `queue`.
    private let writer: AACFileWriter
    private let converter = BufferConverter(target: AudioFormats.storage)
    private var failed = false
    private var isPaused = false
    private var meter = LevelMeter()
    /// Frames written as captured, and frames of silence added.
    private var audioFrames: Int64 = 0
    private var silenceFrames: Int64 = 0

    /// `levels` gets the level of every 50 ms of the track, from the audio before it is written,
    /// from the private queue of the track. `startUptime` is the start of the recording.
    init(
        track: AudioTrack, folder: URL, sink: (any AudioBufferSink)?,
        levels: (@Sendable (AudioTrack, TrackLevel) -> Void)? = nil,
        startUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) throws {
        self.track = track
        self.sink = sink
        self.levels = levels
        self.startUptime = startUptime
        queue = DispatchQueue(label: "com.larp.LARP.capture.\(track.fileName)", qos: .userInitiated)
        writer = try AACFileWriter(url: track.fileURL(in: folder))
    }

    /// Called from an audio thread. The buffer is copied: the caller may reuse it
    /// as soon as this returns.
    func ingest(borrowing buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard let copy = buffer.copy() else {
            drops.record(.unreadable)
            return
        }
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
    /// filled with silence first, so that the track is as long as the recording whether
    /// its source is lost, stopped delivering audio or is still running. `nil` leaves the
    /// track as it is, for a track that never started (it stays empty). Returns what the
    /// track holds.
    @discardableResult
    func finish(silenceUntil end: TimeInterval? = nil) async -> TrackStats {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if let end, !failed { fillSilence(until: end) }
                writer.close()
                let rate = AudioFormats.storageSampleRate
                continuation.resume(
                    returning: TrackStats(audioSeconds: Double(audioFrames) / rate, silenceSeconds: Double(silenceFrames) / rate))
            }
        }
    }

    // MARK: - On the queue

    /// While paused, the audio captured is replaced by silence of the same length; resuming
    /// takes the captured audio again. The change is queued behind the audio already ingested.
    func setPaused(_ paused: Bool) {
        queue.async { [self] in isPaused = paused }
    }

    /// Hands the levels of the 50 ms windows that `buffer` completes to `levels`.
    private func measure(_ buffer: AVAudioPCMBuffer) {
        guard let levels, let data = buffer.floatChannelData else { return }
        let track = track
        meter.consume(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength))) { level in
            levels(track, level)
        }
    }

    private func process(_ input: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard !failed else { return }
        let rate = AudioFormats.storageSampleRate
        do {
            let converted: AVAudioPCMBuffer
            do {
                converted = try converter.convert(input)
            } catch {
                drops.record(.conversionFailed)
                throw error
            }
            // `user.PAUSE_RECORDING`: while paused the track takes silence of the same length
            // as the audio captured, and so does the live transcription.
            if isPaused, let data = converted.floatChannelData {
                data[0].update(repeating: 0, count: Int(converted.frameLength))
            }
            // Audio that is missing since the start of the recording or since the last audio
            // (a device that changed, a source that started late) would shift every later
            // time: fill it with silence.
            let expected = arrival - startUptime
            let written = Double(writer.framesWritten + Int64(converted.frameLength)) / rate
            if expected - written > Self.gapTolerance {
                try writeSilence(seconds: expected - written)
            }
            measure(converted)
            try writer.write(converted)
            audioFrames += Int64(converted.frameLength)
            sink?.consume(AudioChunk(buffer: converted), track: track)
        } catch {
            failed = true
            Self.logger.error("Capture of \(self.track.fileName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fills what is missing up to `end` with silence, whatever its length.
    private func fillSilence(until end: TimeInterval) {
        let missing = end - startUptime - Double(writer.framesWritten) / AudioFormats.storageSampleRate
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
            silenceFrames += Int64(silence.frameLength)
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
