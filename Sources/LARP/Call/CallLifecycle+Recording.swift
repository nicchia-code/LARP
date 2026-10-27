import Foundation
import Synchronization
import os

/// The recording in progress: the call, its live transcription and the task that
/// stores the live lines.
struct ActiveRecording {
    let call: Call
    let relay: LiveAudioRelay
    var session: (any LiveTranscriptionSession)?
    var linesTask: Task<Void, Never>?
}

/// Hands the captured audio to the live transcription. The capture starts before
/// the speech models are loaded; the audio captured meanwhile is kept and given to
/// the session as soon as it exists, so the live transcription covers the whole
/// recording.
final class LiveAudioRelay: AudioBufferSink {
    private struct State {
        var session: (any LiveTranscriptionSession)?
        var pending: [(chunk: AudioChunk, track: AudioTrack)] = []
        var isOpen = true
    }

    private let state = Mutex(State())

    func consume(_ chunk: AudioChunk, track: AudioTrack) {
        state.withLock { state in
            guard state.isOpen else { return }
            if let session = state.session {
                session.consume(chunk, track: track)
            } else {
                state.pending.append((chunk, track))
            }
        }
    }

    /// Gives the audio kept so far to `session`, and everything that follows.
    func attach(_ session: any LiveTranscriptionSession) {
        state.withLock { state in
            for (chunk, track) in state.pending {
                session.consume(chunk, track: track)
            }
            state.pending = []
            state.session = session
        }
    }

    /// Drops the audio kept and ignores what follows: there is no live transcription.
    func close() {
        state.withLock { state in
            state.pending = []
            state.isOpen = false
        }
    }
}

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "recording") }

    /// `recorder.RECORDING_STARTED`: a call is born in **Recording**. The microphone
    /// and the system audio are saved as two tracks; when the chosen language is
    /// ready both are transcribed live in the background.
    func recordingStarted(callAppName: String?) async {
        guard activeRecording == nil else { return }

        let call = Call(
            startedAt: now(), callAppName: callAppName,
            transcriptionLanguage: chosenLanguage(), state: .recording)
        context.insert(call)
        save()

        // Capture first: nothing said is lost while the speech models load.
        let relay = LiveAudioRelay()
        do {
            try await capture.start(into: call.recordingsFolderURL, sink: relay)
        } catch {
            Self.logger.error("Capture did not start: \(error.localizedDescription, privacy: .public)")
            // The call born for this recording goes away; the user is told why.
            try? ArchiveStore.delete(call, in: context)
            captureFailureAlerts.present(reason: error.localizedDescription)
            endRecorderRecording()
            return
        }
        var recording = ActiveRecording(call: call, relay: relay)
        activeRecording = recording

        // Live transcription starts only if the language is ready now: a language
        // that becomes ready later does not start it halfway.
        let language = call.transcriptionLanguage
        if await languages.isReady(language) {
            do {
                let session = try await transcription.startLiveSession(language: language)
                recording.session = session
                recording.linesTask = Task {
                    for await line in session.lines {
                        self.appendLiveLine(line, to: call)
                    }
                }
                relay.attach(session)
            } catch {
                Self.logger.error("Live transcription did not start: \(error.localizedDescription, privacy: .public)")
                relay.close()
            }
        } else {
            relay.close()
        }
        activeRecording = recording
    }

    /// `recorder.RECORDING_STOPPED`: the call ends and moves on according to how
    /// much of it was transcribed live and whether its language is ready.
    func recordingStopped() async {
        guard let recording = activeRecording else { return }
        activeRecording = nil

        await capture.stop()
        var fullyTranscribedLive = false
        if let session = recording.session {
            fullyTranscribedLive = await session.finish()
            await recording.linesTask?.value
        }
        recording.relay.close()

        let call = recording.call
        let endedAt = now()
        call.endedAt = endedAt
        call.duration = max(0, endedAt.timeIntervalSince(call.startedAt))
        if !fullyTranscribedLive {
            // Part of the recording was not transcribed live: it is transcribed again
            // from the audio, as a whole.
            discardLines(of: call)
        }
        let languageReady = await languages.isReady(call.transcriptionLanguage)
        apply(.recordingStopped(fullyTranscribedLive: fullyTranscribedLive, languageReady: languageReady), to: call)
    }

    /// `macos.APP_LAUNCHED` for the calls left in **Recording** (the app was closed
    /// or the Mac turned off): each ends at its last audio saved and is transcribed
    /// again from its audio, or waits for its language.
    func recoverInterruptedRecordings() async {
        for call in calls(in: [.recording]) where call.id != activeRecording?.call.id {
            let seconds = [AudioTrack.microphone, .system]
                .compactMap { AudioFileDuration.seconds(of: $0.fileURL(of: call)) }
                .max() ?? 0
            call.duration = seconds
            call.endedAt = call.startedAt.addingTimeInterval(seconds)
            discardLines(of: call)
            let languageReady = await languages.isReady(call.transcriptionLanguage)
            apply(.appLaunched(languageReady: languageReady), to: call)
        }
    }

    /// Stores a final line of the live transcription.
    private func appendLiveLine(_ line: TranscribedLine, to call: Call) {
        call.lines.append(
            TranscriptLine(speakerKind: line.speaker, start: line.start, end: line.end, text: line.text))
    }

    /// Removes the transcript lines of the call: a partial transcript.
    func discardLines(of call: Call) {
        for line in call.lines {
            context.delete(line)
        }
        call.lines = []
    }
}
