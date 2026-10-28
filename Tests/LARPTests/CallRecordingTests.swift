import AVFoundation
import Foundation
import SwiftData
import Testing

@testable import LARP

@Suite("Call recording", .serialized)
@MainActor
struct CallRecordingTests {
    // MARK: State chosen when the recording stops (the transition table)

    @Test(
        "when the recording stops the call goes where the transcription stands",
        arguments: [
            (true, true, CallState.separatingParticipants),
            (true, false, .separatingParticipants),
            (false, true, .transcribing),
            (false, false, .awaitingLanguage),
        ])
    func stateAtEndOfRecording(fullyTranscribedLive: Bool, languageReady: Bool, expected: CallState) {
        let target = CallStateMachine.target(
            from: .recording,
            on: .recordingStopped(fullyTranscribedLive: fullyTranscribedLive, languageReady: languageReady))
        #expect(target == .state(expected))
    }

    @Test(
        "at launch a call left in Recording goes where its language stands",
        arguments: [(true, CallState.transcribing), (false, .awaitingLanguage)])
    func stateAtLaunch(languageReady: Bool, expected: CallState) {
        #expect(CallStateMachine.target(from: .recording, on: .appLaunched(languageReady: languageReady)) == .state(expected))
    }

    // MARK: A call is born when the recording starts

    @Test("a call is created in Recording when the recorder starts, with the chosen language and call app")
    func callIsCreated() async throws {
        let harness = try CallHarness(chosenLanguage: "en-US")
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: "Zoom"))

        let call = try #require(try harness.allCalls().first)
        #expect(try harness.allCalls().count == 1)
        #expect(call.state == .recording)
        #expect(call.callAppName == "Zoom")
        #expect(call.transcriptionLanguage == "en-US")
        #expect(call.endedAt == nil)
        #expect(harness.capture.startedFolders == [call.recordingsFolderURL])
    }

    @Test("a manual recording has no call app")
    func manualRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))

        #expect(try harness.allCalls().first?.callAppName == nil)
    }

    @Test("the system audio is optional for a recording started by hand and required for one tied to a call app")
    func systemAudioPolicy() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))
        await harness.lifecycle.handle(.stopped)
        await harness.lifecycle.handle(.started(callAppName: "Zoom"))

        #expect(harness.capture.systemAudioPolicies == [.optional, .required])
    }

    @Test("a recording that cannot start leaves no call behind and tells the user why")
    func captureFailure() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.capture.failNextStart(with: MicrophoneCapture.CaptureError.noInputDevice)

        await harness.lifecycle.handle(.started(callAppName: nil))

        #expect(try harness.allCalls().isEmpty)
        #expect(harness.captureAlerts.reasons == ["Nessun microfono disponibile."])
        #expect(harness.recorderEnds.count == 1)
    }

    @Test("a recording that starts shows no alert")
    func captureSuccessNoAlert() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))

        #expect(harness.captureAlerts.reasons.isEmpty)
        #expect(harness.recorderEnds.count == 0)
    }

    // MARK: Live transcription

    @Test("when the language is ready the recording is transcribed live and ends in Separating participants")
    func liveTranscriptionComplete() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let session = FakeLiveSession(completes: true)
        harness.transcription.set { $0.liveSession = session }

        await harness.lifecycle.handle(.started(callAppName: "Teams"))
        session.emit(TranscribedLine(speaker: .others, start: 2, end: 4, text: "Buongiorno"))
        session.emit(TranscribedLine(speaker: .me, start: 0, end: 1.5, text: "Ciao"))
        harness.advanceClock(by: 90)
        await harness.lifecycle.handle(.stopped)

        let call = try #require(try harness.allCalls().first)
        #expect(harness.transcription.liveStarts == ["it-IT"])
        #expect(call.state == .separatingParticipants)
        #expect(call.duration == 90)
        #expect(call.endedAt == call.startedAt.addingTimeInterval(90))
        #expect(harness.capture.stopCount == 1)
        let lines = call.lines.sorted { $0.start < $1.start }
        #expect(lines.map(\.text) == ["Ciao", "Buongiorno"])
        #expect(lines.map(\.speakerKind) == [.me, .others])
    }

    @Test("the audio captured while the live transcription starts is not lost")
    func audioBeforeSessionIsKept() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let session = FakeLiveSession()
        harness.transcription.set { $0.liveSession = session }

        await harness.lifecycle.handle(.started(callAppName: nil))
        let sink = try #require(harness.capture.sink)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: 160))
        buffer.frameLength = 160
        sink.consume(AudioChunk(buffer: buffer), track: .microphone)
        sink.consume(AudioChunk(buffer: buffer), track: .system)

        #expect(session.consumedTracks == [.microphone, .system])
    }

    @Test("when part of the recording was not transcribed live the call is transcribed again from its audio")
    func liveTranscriptionIncomplete() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let session = FakeLiveSession(completes: false)
        harness.transcription.set {
            $0.liveSession = session
            $0.blocksFiles = true
        }

        await harness.lifecycle.handle(.started(callAppName: nil))
        session.emit(TranscribedLine(speaker: .me, start: 0, end: 1, text: "parziale"))
        await harness.lifecycle.handle(.stopped)

        let call = try #require(try harness.allCalls().first)
        #expect(call.state == .transcribing)
        #expect(await harness.eventually { harness.transcription.transcribedFiles.count == 2 })
        #expect(call.lines.isEmpty)

        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    @Test("when the language is not ready nothing is transcribed live and the call awaits the language")
    func languageNotReady() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))
        await harness.lifecycle.handle(.stopped)

        let call = try #require(try harness.allCalls().first)
        #expect(harness.transcription.liveStarts.isEmpty)
        #expect(call.state == .awaitingLanguage)
        #expect(call.lines.isEmpty)
    }

    @Test("a language that becomes ready during the recording does not start the live transcription")
    func languageReadyDuringRecording() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        harness.transcription.set { $0.blocksFiles = true }

        await harness.lifecycle.handle(.started(callAppName: nil))
        harness.languages.becomeReady("it-IT")
        await harness.lifecycle.handle(.stopped)

        let call = try #require(try harness.allCalls().first)
        #expect(harness.transcription.liveStarts.isEmpty)
        // At the end the language is ready but nothing was transcribed live.
        #expect(call.state == .transcribing)

        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    @Test("when the live transcription cannot start the recording goes on and is transcribed afterwards")
    func liveTranscriptionFailsToStart() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.transcription.set {
            $0.liveFailure = FakeTranscriptionFailure()
            $0.blocksFiles = true
        }

        await harness.lifecycle.handle(.started(callAppName: nil))
        await harness.lifecycle.handle(.stopped)

        let call = try #require(try harness.allCalls().first)
        #expect(call.state == .transcribing)
        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    @Test("a stop without a recording is ignored, and a second start while recording too")
    func strayEvents() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.stopped)
        await harness.lifecycle.handle(.started(callAppName: "A"))
        await harness.lifecycle.handle(.started(callAppName: "B"))

        #expect(try harness.allCalls().count == 1)
        #expect(harness.capture.stopCount == 0)
    }

    // MARK: Recovery at launch

    /// Writes `seconds` of audio to the track file the way the capture does, without
    /// closing the file: the state a crash leaves behind.
    private func writeInterruptedAudio(for call: Call, track: AudioTrack, seconds: Int) throws -> AACFileWriter {
        try FileManager.default.createDirectory(at: call.recordingsFolderURL, withIntermediateDirectories: true)
        let writer = try AACFileWriter(url: track.fileURL(of: call))
        let rate = Int(AudioFormats.storageSampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: AVAudioFrameCount(rate)))
        buffer.frameLength = AVAudioFrameCount(rate)
        for index in 0..<rate {
            buffer.floatChannelData![0][index] = 0.3 * sinf(Float(index) * 0.1)
        }
        for _ in 0..<seconds {
            try writer.write(buffer)
        }
        return writer
    }

    @Test("at launch a call left in Recording ends at its last audio saved and is transcribed again")
    func recoveryWithLanguageReady() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.transcription.set { $0.blocksFiles = true }
        let call = try harness.insertCall(.recording, withAudio: false)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "parziale"))
        // 5 seconds written, flushed every 2: 4 are on disk.
        let writer = try writeInterruptedAudio(for: call, track: .microphone, seconds: 5)
        defer { writer.close() }

        await harness.lifecycle.appLaunched()

        #expect(call.state == .transcribing)
        #expect(abs(call.duration - 4) < 0.2)
        #expect(call.endedAt == call.startedAt.addingTimeInterval(call.duration))
        #expect(await harness.eventually { harness.transcription.transcribedFiles.count == 2 })
        #expect(call.lines.isEmpty)

        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    @Test("at launch a call left in Recording awaits its language when it is not ready")
    func recoveryWithLanguageMissing() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.recording, withAudio: false)
        let writer = try writeInterruptedAudio(for: call, track: .system, seconds: 3)
        defer { writer.close() }

        await harness.lifecycle.appLaunched()

        #expect(call.state == .awaitingLanguage)
        #expect(abs(call.duration - 2) < 0.2)
        #expect(harness.transcription.transcribedFiles.isEmpty)
    }

    @Test("a call left in Recording with no readable audio ends with zero duration")
    func recoveryWithoutAudio() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.recording, withAudio: false)

        await harness.lifecycle.appLaunched()

        #expect(call.state == .awaitingLanguage)
        #expect(call.duration == 0)
        #expect(call.endedAt == call.startedAt)
    }

    @Test("a call is recovered before the recorder events are handled")
    func recoveryComesFirst() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        let old = try harness.insertCall(.recording, withAudio: false)
        let (events, continuation) = AsyncStream<RecorderEvent>.makeStream()
        continuation.yield(.started(callAppName: nil))

        harness.lifecycle.start(recorderEvents: events)

        #expect(await harness.eventually { (try? harness.allCalls().count) == 2 })
        #expect(old.state == .awaitingLanguage)
        let calls = try harness.allCalls()
        let recording = try #require(calls.first { $0.id != old.id })
        #expect(recording.state == .recording)
        continuation.finish()
    }
}
