import AVFoundation
import Foundation
import SwiftData
import Testing

@testable import LARP

/// Audio files for the tests: a track of `seconds` made of pieces, each at a constant amplitude.
private enum TestAudio {
    /// Writes linear PCM with `amplitudes` spread evenly over `seconds`.
    @discardableResult
    static func write(
        to url: URL, seconds: Double, amplitudes: [Float], sampleRate: Double = 16_000, channels: AVAudioChannelCount = 1
    ) throws -> URL {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<Int(channels) {
            for index in 0..<Int(frames) {
                let piece = min(index * amplitudes.count / Int(frames), amplitudes.count - 1)
                buffer.floatChannelData![channel][index] = amplitudes[piece] * (index % 2 == 0 ? 1 : -1)
            }
        }
        try file.write(from: buffer)
        return url
    }

    static func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "larp-\(UUID().uuidString)").appending(path: name)
    }
}

@Suite("Waveform", .serialized, .italianInterface)
@MainActor
struct WaveformTests {
    // MARK: Levels and speakers

    @Test("a peak is a level on a scale from -50 dBFS to 0 dBFS")
    func scale() {
        #expect(Waveform.level(peak: 1) == 1)
        #expect(Waveform.level(peak: 0) == 0)
        #expect(Waveform.level(peak: 0.001) == 0)  // -60 dBFS
        #expect(abs(Waveform.level(peak: powf(10, -25 / 20)) - 0.5) < 1e-6)  // -25 dBFS
        #expect(Waveform.level(peak: 2) == 1)
    }

    @Test("a bar takes the speaker of the line covering the middle of its time, silence when none does")
    func speakers() {
        let lines = [
            WaveformLine(start: 0, end: 4, speaker: .me),
            WaveformLine(start: 4, end: 7, speaker: .participant(2)),
            WaveformLine(start: 8, end: 10, speaker: .others),
        ]
        // Four bars over 10 seconds: their middles are 1.25, 3.75, 6.25 and 8.75.
        let bars = Waveform.bars(peaks: [1, 1, 1, 1], duration: 10, lines: lines)
        #expect(bars.map(\.speaker) == [.me, .me, .participant(2), .others])
        let gap = Waveform.bars(peaks: [1, 1], duration: 16, lines: lines)  // middles 4 and 12
        #expect(gap.map(\.speaker) == [.participant(2), .silence])
    }

    @Test("a line of the others without participant counts as the others")
    func lineWithoutParticipant() {
        let line = TranscriptLine(speakerKind: .participant, start: 0, end: 1, text: "x")
        #expect(line.waveformLine.speaker == .others)
        #expect(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "x").waveformLine.speaker == .me)
    }

    // MARK: Reading

    @Test("the peaks of both tracks are measured over equal parts of the call, the larger of the two")
    func peaksOfBothTracks() async throws {
        let mic = try TestAudio.write(to: TestAudio.temporaryURL("mic.caf"), seconds: 4, amplitudes: [0.5, 0, 0, 0])
        let system = try TestAudio.write(to: TestAudio.temporaryURL("system.caf"), seconds: 4, amplitudes: [0.1, 0.8, 0, 0])
        defer {
            try? FileManager.default.removeItem(at: mic.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: system.deletingLastPathComponent())
        }

        let measure = try #require(try await WaveformReader.peaks(of: [mic, system], duration: 4, bars: 4))

        #expect(measure.peaks.count == 4)
        #expect(abs(measure.peaks[0] - 0.5) < 1e-4)
        #expect(abs(measure.peaks[1] - 0.8) < 1e-4)
        #expect(measure.peaks[2] == 0 && measure.peaks[3] == 0)
    }

    @Test("a track is read in blocks and its bars cover the whole call")
    func longTrack() async throws {
        let url = try TestAudio.write(
            to: TestAudio.temporaryURL("system.caf"), seconds: 30, amplitudes: Array(repeating: 0.25, count: 30))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let measure = try #require(try await WaveformReader.peaks(of: [url], duration: 30))

        #expect(measure.peaks.count == Waveform.barCount)
        #expect(measure.peaks.allSatisfy { abs($0 - 0.25) < 1e-4 })
    }

    @Test("with no readable track there is nothing to measure")
    func nothingToMeasure() async throws {
        let missing = TestAudio.temporaryURL("mic.caf")
        #expect(try await WaveformReader.peaks(of: [missing], duration: 10) == nil)
    }

    // MARK: When it is worked out

    private func writeTracks(of call: Call, mic: [Float], system: [Float], seconds: Double = 8) throws {
        try TestAudio.write(to: AudioTrack.microphone.fileURL(of: call), seconds: seconds, amplitudes: mic)
        try TestAudio.write(to: AudioTrack.system.fileURL(of: call), seconds: seconds, amplitudes: system)
    }

    @Test("a call that becomes ready gets its waveform, coloured by who speaks, saved with the call")
    func becomesReady() async throws {
        let harness = try CallHarness(separator: FakeSeparator(.succeed))
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.separatingParticipants, withAudio: false)
        call.duration = 8
        try writeTracks(of: call, mic: [0.5, 0.5, 0, 0], system: [0, 0, 0.2, 0.2])
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 4, text: "uno"))
        let participant = Participant(number: 2)
        call.participants.append(participant)
        call.lines.append(TranscriptLine(speakerKind: .participant, participant: participant, start: 4, end: 7, text: "due"))

        harness.lifecycle.startSeparationForTest(call)
        await harness.lifecycle.waitUntilSeparationIdle()
        await harness.lifecycle.waitUntilWaveformIdle()

        #expect(call.state == .ready)
        let bars = try #require(call.waveform)
        #expect(bars.count == Waveform.barCount)
        #expect(bars.first?.speaker == .me)
        #expect(abs((bars.first?.level ?? 0) - Waveform.level(peak: 0.5)) < 1e-6)
        #expect(bars.last?.speaker == .silence)
        let middle = bars[Waveform.barCount * 3 / 4]
        #expect(middle.speaker == .participant(2))
        #expect(abs(middle.level - Waveform.level(peak: 0.2)) < 1e-6)
    }

    @Test("a separation that runs again gives the call a new waveform; a failed one leaves the waveform alone")
    func separationRunsAgain() async throws {
        let stale = [WaveformBar(level: 0.99, speaker: .others)]
        for (behavior, succeeds) in [(FakeSeparator.Behavior.succeed, true), (.fail, false)] {
            let harness = try CallHarness(separator: FakeSeparator(behavior))
            defer { harness.cleanUp() }
            let call = try harness.insertCall(.separatingParticipants, withAudio: false)
            call.duration = 8
            try writeTracks(of: call, mic: [0.5, 0], system: [0, 0.2])
            call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 4, text: "uno"))
            call.waveform = stale

            harness.lifecycle.startSeparationForTest(call)
            await harness.lifecycle.waitUntilSeparationIdle()
            await harness.lifecycle.waitUntilWaveformIdle()

            if succeeds {
                #expect(call.state == .ready)
                #expect(call.waveform?.count == Waveform.barCount)
                #expect(call.waveform?.first?.speaker == .me)
            } else {
                #expect(call.state == .awaitingSeparationRetry)
                #expect(call.waveform == stale)
            }
        }
    }

    @Test("a ready call that already has its waveform keeps it; one without audio gets none")
    func notWorkedOutAgain() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let silent = try harness.insertCall(.separatingParticipants, withAudio: false)
        let kept = try harness.insertCall(.refiningTranscript, withAudio: false)
        let bars = [WaveformBar(level: 0.3, speaker: .others)]
        kept.waveform = bars
        try writeTracks(of: kept, mic: [0.9], system: [0.9])

        harness.lifecycle.apply(.participantsSeparated(refinementOn: false), to: silent)
        harness.lifecycle.apply(.transcriptRefined, to: kept)
        await harness.lifecycle.waitUntilWaveformIdle()

        #expect(silent.waveform == nil)
        #expect(kept.waveform == bars)
    }

    @Test("at launch the ready calls without waveform and with audio get it, one at a time, the newest first")
    func backfillAtLaunch() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let old = try harness.insertCall(.ready, startedAt: Date(timeIntervalSince1970: 1_000_000_000), withAudio: false)
        let new = try harness.insertCall(.ready, startedAt: Date(timeIntervalSince1970: 1_700_000_000), withAudio: false)
        let noAudio = try harness.insertCall(.ready, startedAt: Date(timeIntervalSince1970: 1_600_000_000), withAudio: false)
        let done = try harness.insertCall(.ready, startedAt: Date(timeIntervalSince1970: 1_500_000_000), withAudio: false)
        for call in [old, new] {
            call.duration = 8
            try writeTracks(of: call, mic: [0.4], system: [0.1])
        }
        let existing = [WaveformBar(level: 1, speaker: .me)]
        done.waveform = existing

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilWaveformIdle()

        #expect(old.waveform?.count == Waveform.barCount)
        #expect(new.waveform?.count == Waveform.barCount)
        #expect(noAudio.waveform == nil)
        #expect(done.waveform == existing)
    }

    @Test("the waveform of a call deleted while it is read is not saved")
    func deletedWhileReading() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.separatingParticipants, withAudio: false)
        call.duration = 8
        try writeTracks(of: call, mic: [0.4], system: [0.1])

        harness.lifecycle.apply(.participantsSeparated(refinementOn: false), to: call)
        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilWaveformIdle()

        #expect(try harness.allCalls().isEmpty)
    }
}

extension CallLifecycle {
    /// Starts the work of **Separating participants** for a call put in that state by a test.
    fileprivate func startSeparationForTest(_ call: Call) {
        enter(.separatingParticipants, call: call)
    }
}

@Suite("Import of audio files", .serialized, .italianInterface)
@MainActor
struct AudioImportTests {
    private func sourceFile(named name: String = "Riunione budget.wav", channels: AVAudioChannelCount = 2) throws -> URL {
        try TestAudio.write(
            to: TestAudio.temporaryURL(name), seconds: 2, amplitudes: [0.3, 0.3], sampleRate: 44_100, channels: channels)
    }

    // MARK: Transition

    @Test("an imported file goes to Transcribing when the language is ready, else to Awaiting language")
    func stateAfterImport() {
        #expect(CallStateMachine.stateAfterImport(languageReady: true) == .transcribing)
        #expect(CallStateMachine.stateAfterImport(languageReady: false) == .awaitingLanguage)
    }

    // MARK: Conversion

    @Test("any readable file becomes the system audio track at the format of a recording, and is left alone")
    func conversion() async throws {
        let source = try sourceFile()
        let destination = TestAudio.temporaryURL("system.caf")
        defer {
            try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
        }
        let before = try FileManager.default.attributesOfItem(atPath: source.path)

        let imported = try await AudioFileImporter.convert(source, to: destination)

        let converted = try AVAudioFile(forReading: destination)
        #expect(converted.fileFormat.channelCount == 1)
        #expect(converted.fileFormat.sampleRate == AudioFormats.storageSampleRate)
        #expect(converted.fileFormat.settings[AVFormatIDKey] as? UInt32 == kAudioFormatMPEG4AAC)
        #expect(abs(Double(converted.length) / converted.processingFormat.sampleRate - 2) < 0.2)
        #expect(abs(imported.duration - 2) < 0.01)
        let after = try FileManager.default.attributesOfItem(atPath: source.path)
        #expect(before[.modificationDate] as? Date == after[.modificationDate] as? Date)
        #expect(before[.size] as? Int == after[.size] as? Int)
        #expect(imported.modifiedAt == after[.modificationDate] as? Date)
    }

    @Test("a file that is not audio cannot be converted")
    func notAudio() async throws {
        let folder = TestAudio.temporaryURL("x").deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appending(path: "nota.mp3")
        try Data("not audio at all".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: folder) }

        await #expect(throws: (any Error).self) {
            try await AudioFileImporter.convert(source, to: folder.appending(path: "out/system.caf"))
        }
    }

    // MARK: The call

    @Test("the call is born from the file: its name as title, its modification time as start, its length as duration")
    func callIsBorn() async throws {
        let harness = try CallHarness(readyLanguages: ["en-US"], chosenLanguage: "en-US")
        defer { harness.cleanUp() }
        harness.transcription.set { $0.blocksFiles = true }
        let source = try sourceFile()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let modified = Date(timeIntervalSince1970: 1_650_000_000)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: source.path)

        let call = try #require(await harness.lifecycle.importAudio(from: source))

        #expect(try harness.allCalls().count == 1)
        #expect(call.title == "Riunione budget")
        #expect(call.startedAt == modified)
        #expect(abs(call.duration - 2) < 0.01)
        #expect(call.endedAt == modified.addingTimeInterval(call.duration))
        #expect(call.callAppName == nil)
        #expect(call.transcriptionLanguage == "en-US")
        #expect(call.isImported)
        #expect(call.state == .transcribing)
        #expect(FileManager.default.fileExists(atPath: call.systemAudioURL.path))
        #expect(!FileManager.default.fileExists(atPath: call.micAudioURL.path))
        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    @Test("a call whose language is not ready waits for it")
    func awaitingLanguage() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        let source = try sourceFile(channels: 1)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        let call = try #require(await harness.lifecycle.importAudio(from: source))

        #expect(call.state == .awaitingLanguage)
    }

    @Test("an imported call is transcribed from its system audio and every voice becomes a participant")
    func transcribedAndSeparated() async throws {
        let harness = try CallHarness(separator: FakeSeparator(.succeed))
        defer { harness.cleanUp() }
        harness.transcription.set {
            $0.fileLines = [.others: [TranscribedLine(speaker: .others, start: 0, end: 1, text: "Buongiorno")]]
        }
        let source = try sourceFile()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        let call = try #require(await harness.lifecycle.importAudio(from: source))
        await harness.lifecycle.waitUntilTranscriptionIdle()

        await harness.lifecycle.waitUntilSeparationIdle()
        await harness.lifecycle.waitUntilWaveformIdle()

        #expect(call.state == .ready)
        #expect(call.lines.map(\.speakerKind) == [.others])
        #expect(call.lines.map(\.text) == ["Buongiorno"])
        #expect(Set(harness.transcription.transcribedFiles.map(\.lastPathComponent)) == ["mic.caf", "system.caf"])
    }

    @Test("a file that cannot be converted makes no call, leaves no audio and tells the user why")
    func failure() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let folder = TestAudio.temporaryURL("x").deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appending(path: "rotto.m4a")
        try Data("not audio at all".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: folder) }

        let call = await harness.lifecycle.importAudio(from: source)

        #expect(call == nil)
        #expect(try harness.allCalls().isEmpty)
        #expect(harness.importAlerts.reasons.count == 1)
        #expect(harness.importAlerts.reasons.first?.isEmpty == false)
    }

    @Test("a call stored before imports existed opens as not imported and with no waveform")
    func defaults() throws {
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        #expect(!call.isImported)
        #expect(call.waveform == nil)
    }
}

@Suite("Correction of the text of a line", .serialized, .italianInterface)
@MainActor
struct LineCorrectionTests {
    private func readyCall(_ harness: CallHarness) throws -> (Call, TranscriptLine) {
        let call = try harness.insertCall(.ready)
        let line = TranscriptLine(speakerKind: .me, start: 1, end: 2, text: "Ciao a tutto")
        call.lines.append(line)
        try harness.context.save()
        return (call, line)
    }

    @Test("only a ready call reacts, for a line of its own and a text that is not empty once trimmed")
    func transitionTable() {
        let edit = { CallEvent.editLine(lineBelongsToCall: $0, textIsEmpty: $1) }
        #expect(CallStateMachine.target(from: .ready, on: edit(true, false)) == .state(.ready))
        #expect(CallStateMachine.target(from: .ready, on: edit(false, false)) == nil)
        #expect(CallStateMachine.target(from: .ready, on: edit(true, true)) == nil)
        for state in CallState.allCases where state != .ready {
            #expect(CallStateMachine.target(from: state, on: edit(true, false)) == nil, "\(state)")
        }
    }

    @Test("the line takes the new text and keeps its speaker")
    func lineTakesText() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let (call, line) = try readyCall(harness)

        harness.lifecycle.editLine(line, of: call, to: "  Ciao a tutti  ")

        #expect(line.text == "Ciao a tutti")
        #expect(line.speakerKind == .me)
        #expect(call.state == .ready)
        #expect(line.originalText == nil)
        #expect(!call.isRefined)
    }

    @Test("an empty text leaves the line as it was")
    func emptyText() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let (call, line) = try readyCall(harness)

        harness.lifecycle.editLine(line, of: call, to: "  \n ")

        #expect(line.text == "Ciao a tutto")
    }

    @Test("a line of another call is not changed")
    func lineOfAnotherCall() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let (_, line) = try readyCall(harness)
        let other = try harness.insertCall(.ready)

        harness.lifecycle.editLine(line, of: other, to: "Altro")

        #expect(line.text == "Ciao a tutto")
    }

    @Test("a call that is not ready cannot be corrected")
    func notReady() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.awaitingLanguage)
        let line = TranscriptLine(speakerKind: .others, start: 0, end: 1, text: "prima")
        call.lines.append(line)

        harness.lifecycle.editLine(line, of: call, to: "dopo")

        #expect(line.text == "prima")
        #expect(!harness.lifecycle.canEditLines(of: call))
    }

    @Test("a refined line takes the text over its original too, so restoring brings back the corrected text")
    func refinedLine() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let (call, line) = try readyCall(harness)
        line.originalText = "Ciao a tuto"
        line.originalSpeakerKind = .others
        line.text = "Ciao a tutto"

        harness.lifecycle.editLine(line, of: call, to: "Ciao a tutti")

        #expect(line.text == "Ciao a tutti")
        #expect(line.originalText == "Ciao a tutti")
        #expect(line.originalSpeakerKind == .others)
        #expect(line.speakerKind == .me)
        #expect(call.isRefined)

        harness.lifecycle.restoreTranscript(call)

        #expect(line.text == "Ciao a tutti")
        #expect(line.speakerKind == .others)
        #expect(!call.isRefined)
    }

    @Test("a translation shown, or in progress, is dropped when a line is corrected, and the corrected text shows")
    func translationDropped() async throws {
        let answers: [(any TranscriptRefining, Bool)] = [(AnswerAssistant(), true), (HangingAssistant(), false)]
        for (assistant, finishes) in answers {
            let harness = try CallHarness()
            defer { harness.cleanUp() }
            let (call, line) = try readyCall(harness)
            let participant = Participant(number: 1)
            call.participants.append(participant)
            call.lines.append(TranscriptLine(speakerKind: .participant, participant: participant, start: 3, end: 4, text: "Va bene"))
            try harness.context.save()
            let model = MainWindowModel(translation: TranscriptTranslation(assistant: assistant, isOn: { true }))

            #expect(model.translation.translate(call))
            if finishes {
                await model.translation.waitUntilIdle()
                #expect(model.translation.state == .translated)
                #expect(model.translation.text(of: line) == "Hello to all")
            } else {
                #expect(model.translation.state == .translating)
            }

            model.editLine(line, of: call, to: "Ciao a tutti", lifecycle: harness.lifecycle)

            #expect(model.translation.state == .original)
            #expect(model.translation.text(of: line) == nil)
            #expect(line.text == "Ciao a tutti")
        }
    }
}

/// Answers a translation with a fixed text for every line.
private struct AnswerAssistant: TranscriptRefining {
    @concurrent func refine(prompt: String) async throws -> String {
        #"[{"number": 1, "text": "Hello to all"}, {"number": 2, "text": "Fine"}]"#
    }
}

/// Never answers; ends with the cancellation of the task.
private struct HangingAssistant: TranscriptRefining {
    @concurrent func refine(prompt: String) async throws -> String {
        try await Task.sleep(for: .seconds(60))
        return ""
    }
}
