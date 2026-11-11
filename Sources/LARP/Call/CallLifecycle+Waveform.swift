import Foundation
import os

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "waveform") }

    /// Works out the waveform of a Ready call that has none and has audio: the tracks are read in blocks
    /// off the main actor, and the bars are saved with the call back on it. Starting again while one is
    /// running does nothing.
    func startWaveform(of call: Call) {
        let id = call.id
        guard call.state == .ready, call.waveform == nil, runningWaveforms[id] == nil else { return }
        let urls = [AudioTrack.microphone, .system]
            .map { $0.fileURL(of: call) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        let duration = call.duration
        waveformCounter += 1
        let token = waveformCounter
        let task = Task {
            await computeWaveform(callID: id, urls: urls, duration: duration)
            if runningWaveforms[id]?.token == token {
                runningWaveforms[id] = nil
            }
        }
        runningWaveforms[id] = (token, task)
    }

    private func computeWaveform(callID: UUID, urls: [URL], duration: TimeInterval) async {
        do {
            guard let measure = try await WaveformReader.peaks(of: urls, duration: duration) else { return }
            try Task.checkCancellation()
            // The call may be gone, or no longer Ready, while its audio was read.
            guard let call = call(id: callID), call.state == .ready else { return }
            call.waveform = Waveform.bars(
                peaks: measure.peaks, duration: measure.duration, lines: call.lines.map(\.waveformLine))
            save()
        } catch is CancellationError {
            // Stopped (the call was deleted): not a failure.
        } catch {
            Self.logger.error("Waveform failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// At launch: the Ready calls without waveform and with audio get it in the background, one at a
    /// time, the most recent first.
    func startWaveformBackfill() {
        guard waveformBackfill == nil else { return }
        let pending = calls(in: [.ready])
            .filter { $0.waveform == nil }
            .sorted { $0.startedAt > $1.startedAt }
            .map(\.id)
        guard !pending.isEmpty else { return }
        waveformBackfill = Task {
            for id in pending {
                guard !Task.isCancelled else { break }
                guard let call = call(id: id) else { continue }
                startWaveform(of: call)
                await runningWaveforms[id]?.task.value
            }
            waveformBackfill = nil
        }
    }

    /// Stops the waveform of the call, if being worked out.
    func cancelWaveform(of callID: UUID) {
        runningWaveforms[callID]?.task.cancel()
    }

    /// Resolves when no waveform is being worked out any more and the launch backfill has ended.
    func waitUntilWaveformIdle() async {
        await waveformBackfill?.value
        while let running = runningWaveforms.values.first {
            await running.task.value
        }
    }
}
