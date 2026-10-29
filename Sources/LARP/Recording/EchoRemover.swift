import AVFoundation
import Foundation
import Synchronization
import os

/// Removes from the microphone the sound of the other participants that it picks up from
/// the Mac's speakers, before the microphone audio goes on to its track (and so to
/// `mic.caf` and the live transcription).
///
/// The system audio is the reference signal and the microphone the one to clean. Both
/// taps hand their audio over from their audio thread, which only copies it and returns:
/// the conversion to 16 kHz mono, the framing in 10 ms and the echo canceller run on a
/// private serial queue, so capture is never blocked.
///
/// While there is no echo canceller (before `reset()` and when it cannot be created) the
/// microphone goes on to its track as captured.
final class EchoRemover: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "echo")
    private static let frameSamples = EchoCanceller.frameSamples

    private let output: TrackPipeline
    private let queue = DispatchQueue(label: "com.larp.LARP.echo", qos: .userInitiated)
    /// Whether an echo canceller exists, readable from the audio threads.
    private let isActive = Mutex(false)

    // Everything below is confined to `queue`.
    private var canceller: EchoCanceller?
    /// `false` while the system audio is lost.
    private var hasReference = true
    private var referenceConverter = BufferConverter(target: AudioFormats.storage)
    private var microphoneConverter = BufferConverter(target: AudioFormats.storage)
    private var referenceSamples: [Float] = []
    private var microphoneSamples: [Float] = []

    /// `output` is the microphone's track: it gets the cleaned audio.
    init(output: TrackPipeline) {
        self.output = output
    }

    /// What the system audio tap hands its audio to.
    var reference: any AudioInput { ReferenceInput(remover: self) }

    /// What the microphone tap hands its audio to.
    var microphone: any AudioInput { MicrophoneInput(remover: self) }

    /// Starts removing the echo with a new echo canceller, which learns the echo path from
    /// scratch: at the start of a recording and every time the microphone starts again
    /// (new microphone or output). Returns `false` when the echo canceller cannot be
    /// created: the microphone is then recorded as captured.
    ///
    /// While the system audio is lost (`suspendReference()`) there is no reference: nothing
    /// is created and this returns `false`.
    func reset() -> Bool {
        queue.sync { restart() }
    }

    /// The system audio is lost: the echo canceller goes away and the microphone goes on to
    /// its track as captured, until `resumeReference()`.
    func suspendReference() {
        queue.sync {
            hasReference = false
            _ = restart()
        }
    }

    /// The system audio is captured again: echo removal resumes as at the start of a
    /// recording. Returns whether the echo canceller could be created.
    func resumeReference() -> Bool {
        queue.sync {
            hasReference = true
            return restart()
        }
    }

    /// On the queue.
    private func restart() -> Bool {
        referenceConverter = BufferConverter(target: AudioFormats.storage)
        microphoneConverter = BufferConverter(target: AudioFormats.storage)
        referenceSamples.removeAll(keepingCapacity: true)
        microphoneSamples.removeAll(keepingCapacity: true)
        canceller = hasReference ? EchoCanceller() : nil
        let created = canceller != nil
        isActive.withLock { $0 = created }
        if hasReference && !created { Self.logger.error("The echo canceller could not be created") }
        return created
    }

    /// Waits until everything handed over so far has gone through the echo canceller and
    /// on to the microphone's track.
    func finish() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                canceller = nil
                isActive.withLock { $0 = false }
                continuation.resume()
            }
        }
    }

    // MARK: - Audio threads

    fileprivate func ingestReference(_ buffer: AVAudioPCMBuffer) {
        guard isActive.withLock({ $0 }), let copy = buffer.copy() else { return }
        let chunk = AudioChunk(buffer: copy)
        queue.async { [self] in
            processReference(chunk.buffer)
        }
    }

    fileprivate func ingestMicrophone(_ buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard isActive.withLock({ $0 }) else {
            output.ingest(borrowing: buffer, arrival: arrival)
            return
        }
        guard let copy = buffer.copy() else { return }
        let chunk = AudioChunk(buffer: copy)
        queue.async { [self] in
            processMicrophone(chunk.buffer, arrival: arrival)
        }
    }

    // MARK: - On the queue

    private func processReference(_ buffer: AVAudioPCMBuffer) {
        guard let canceller, let converted = try? referenceConverter.convert(buffer) else { return }
        append(converted, to: &referenceSamples)
        var consumed = 0
        referenceSamples.withUnsafeBufferPointer { samples in
            while samples.count - consumed >= Self.frameSamples {
                canceller.processReference(samples.baseAddress! + consumed)
                consumed += Self.frameSamples
            }
        }
        referenceSamples.removeFirst(consumed)
    }

    private func processMicrophone(_ buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
        guard let canceller else {
            output.enqueue(buffer, arrival: arrival)
            return
        }
        guard let converted = try? microphoneConverter.convert(buffer) else { return }
        append(converted, to: &microphoneSamples)
        let frames = microphoneSamples.count / Self.frameSamples
        guard frames > 0 else { return }

        let count = frames * Self.frameSamples
        guard let cleaned = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: AVAudioFrameCount(count)),
            let destination = cleaned.floatChannelData?[0]
        else { return }
        cleaned.frameLength = AVAudioFrameCount(count)
        microphoneSamples.withUnsafeBufferPointer { samples in
            for frame in 0..<frames {
                let offset = frame * Self.frameSamples
                // A frame the canceller could not take goes on as captured.
                if !canceller.processMicrophone(samples.baseAddress! + offset, into: destination + offset) {
                    (destination + offset).update(from: samples.baseAddress! + offset, count: Self.frameSamples)
                }
            }
        }
        microphoneSamples.removeFirst(count)
        // The audio waiting for the rest of its frame was captured last: the cleaned audio
        // ends that much before the arrival of the buffer.
        let waiting = Double(microphoneSamples.count) / AudioFormats.storageSampleRate
        output.enqueue(cleaned, arrival: arrival - waiting)
    }

    private func append(_ buffer: AVAudioPCMBuffer, to samples: inout [Float]) {
        guard let data = buffer.floatChannelData?[0] else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
    }

    // MARK: - Inputs

    private struct ReferenceInput: AudioInput {
        let remover: EchoRemover
        func ingest(borrowing buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
            remover.ingestReference(buffer)
        }
    }

    private struct MicrophoneInput: AudioInput {
        let remover: EchoRemover
        func ingest(borrowing buffer: AVAudioPCMBuffer, arrival: TimeInterval) {
            remover.ingestMicrophone(buffer, arrival: arrival)
        }
    }
}
