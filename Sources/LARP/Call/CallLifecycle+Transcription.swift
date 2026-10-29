import Foundation
import os

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "transcription") }

    /// Makes sure the calls in **Transcribing** are transcribed, one at a time, the
    /// oldest first. A running worker picks up calls that arrive meanwhile.
    func scheduleTranscription() {
        guard transcriptionWorker == nil else { return }
        transcriptionWorker = Task {
            while let call = nextCallToTranscribe() {
                await transcribe(call)
            }
            transcriptionWorker = nil
        }
    }

    /// Resolves when the worker has nothing left to transcribe.
    func waitUntilTranscriptionIdle() async {
        await transcriptionWorker?.value
    }

    private func nextCallToTranscribe() -> Call? {
        calls(in: [.transcribing]).first { transcriptionRetries[$0.id] == nil }
    }

    /// What the archive says about the state of the call: a transcription that
    /// failed says so, and that it will be tried again. A call that is Ready says how
    /// its summary is going.
    func statusLabel(of call: Call) -> String? {
        if call.state == .transcribing, failedTranscriptions.contains(call.id) {
            return "Trascrizione non riuscita, nuovo tentativo a breve"
        }
        if call.state == .ready {
            return call.summaryState.statusLabel
        }
        return call.state.statusLabel
    }

    /// After a failure the call stays in **Transcribing** (no new state) and is tried
    /// again once `transcriptionRetryDelay` has passed, as many times as it takes.
    private func scheduleTranscriptionRetry(of id: UUID) {
        transcriptionRetries[id]?.cancel()
        let delay = transcriptionRetryDelay
        transcriptionRetries[id] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            transcriptionRetries[id] = nil
            scheduleTranscription()
        }
    }

    /// Transcribes both tracks of the saved audio, the microphone as "Me" and the
    /// system audio as "Others", in the language of the call, then emits
    /// `TRANSCRIPTION_COMPLETED`. Always from the beginning: any partial transcript
    /// is discarded first.
    private func transcribe(_ call: Call) async {
        let id = call.id
        let language = call.transcriptionLanguage
        let micURL = AudioTrack.microphone.fileURL(of: call)
        let systemURL = AudioTrack.system.fileURL(of: call)
        discardLines(of: call)
        save()

        let service = transcription
        let task = Task.detached {
            async let mine = service.transcribeFile(at: micURL, speaker: .me, language: language)
            async let others = service.transcribeFile(at: systemURL, speaker: .others, language: language)
            return try await mine + others
        }
        runningTranscription = (id, task)
        defer { runningTranscription = nil }

        // Deleting the call cancels the task: whatever it ends with (an error, or lines
        // it produced before noticing) is dropped without reading or writing the call.
        let lines: [TranscribedLine]
        do {
            lines = try await task.value
        } catch {
            if !task.isCancelled, !(error is CancellationError), self.call(id: id) != nil {
                // The call shows the failure and is transcribed again after a wait.
                Self.logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
                failedTranscriptions.insert(id)
                scheduleTranscriptionRetry(of: id)
            }
            return
        }

        guard !task.isCancelled, let call = self.call(id: id), call.state == .transcribing else { return }
        failedTranscriptions.remove(id)
        for line in lines.sorted(by: { $0.start < $1.start }) {
            call.lines.append(
                TranscriptLine(speakerKind: line.speaker, start: line.start, end: line.end, text: line.text))
        }
        apply(.transcriptionCompleted, to: call)
    }
}
