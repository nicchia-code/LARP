import AVFoundation
import Foundation
import Speech
import Synchronization

/// `TranscriptionService` backed by `SpeechAnalyzer`, one `SpeechTranscriber` per
/// track, configured with the chosen language, volatile and final results and audio
/// time ranges. Only final results become lines.
struct SpeechTranscriptionService: TranscriptionService {
    init() {}

    func startLiveSession(language: String) async throws -> any LiveTranscriptionSession {
        let microphone = try await LiveTrackTranscriber.start(language: language, speaker: .me)
        let system: LiveTrackTranscriber
        do {
            system = try await LiveTrackTranscriber.start(language: language, speaker: .others)
        } catch {
            await microphone.cancel()
            throw error
        }
        return SpeechLiveSession(microphone: microphone, system: system)
    }

    func transcribeFile(at url: URL, speaker: SpeakerKind, language: String) async throws -> [TranscribedLine] {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return [] }

        let transcriber = SpeechTrackConfiguration.makeTranscriber(language: language)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collector = Task {
            var lines: [TranscribedLine] = []
            for try await result in transcriber.results {
                if let line = SpeechTrackConfiguration.line(from: result, speaker: speaker) {
                    lines.append(line)
                }
            }
            return lines
        }
        return try await withTaskCancellationHandler {
            do {
                // The analyzer reads the file and converts it to the format of the model.
                _ = try await analyzer.analyzeSequence(from: file)
                try await analyzer.finalizeAndFinishThroughEndOfInput()
                return try await collector.value
            } catch {
                collector.cancel()
                await analyzer.cancelAndFinishNow()
                throw error
            }
        } onCancel: {
            collector.cancel()
            Task { await analyzer.cancelAndFinishNow() }
        }
    }
}

/// The configuration shared by live and file transcription, so both produce the
/// same kind of lines.
enum SpeechTrackConfiguration {
    static func makeTranscriber(language: String) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: Locale(identifier: language),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
    }

    /// The line for a final result; `nil` for volatile results and empty text.
    static func line(from result: SpeechTranscriber.Result, speaker: SpeakerKind) -> TranscribedLine? {
        guard result.isFinal else { return nil }
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let start = result.range.start.seconds
        let end = result.range.end.seconds
        let safeStart = start.isFinite ? max(0, start) : 0
        let safeEnd = end.isFinite ? max(safeStart, end) : safeStart
        return TranscribedLine(speaker: speaker, start: safeStart, end: safeEnd, text: text)
    }
}

/// Live transcription of one track: audio is fed as it is captured.
private final class LiveTrackTranscriber: @unchecked Sendable {
    let lines: AsyncStream<TranscribedLine>
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let resultsTask: Task<Void, any Error>
    private let failed = Mutex(false)
    /// Only used by `append`, which has a single caller at a time.
    private let converter: BufferConverter

    static func start(language: String, speaker: SpeakerKind) async throws -> LiveTrackTranscriber {
        let transcriber = SpeechTrackConfiguration.makeTranscriber(language: language)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechError.noCompatibleFormat
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: format)

        let (inputStream, input) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .unbounded)
        let (lines, linesContinuation) = AsyncStream<TranscribedLine>.makeStream(bufferingPolicy: .unbounded)
        let resultsTask = Task {
            defer { linesContinuation.finish() }
            for try await result in transcriber.results {
                if let line = SpeechTrackConfiguration.line(from: result, speaker: speaker) {
                    linesContinuation.yield(line)
                }
            }
        }
        do {
            try await analyzer.start(inputSequence: inputStream)
        } catch {
            input.finish()
            resultsTask.cancel()
            throw error
        }
        return LiveTrackTranscriber(
            lines: lines, analyzer: analyzer, input: input, resultsTask: resultsTask,
            converter: BufferConverter(target: format))
    }

    private init(
        lines: AsyncStream<TranscribedLine>, analyzer: SpeechAnalyzer,
        input: AsyncStream<AnalyzerInput>.Continuation, resultsTask: Task<Void, any Error>,
        converter: BufferConverter
    ) {
        self.lines = lines
        self.analyzer = analyzer
        self.input = input
        self.resultsTask = resultsTask
        self.converter = converter
    }

    /// Converts `chunk` to the format of the analyzer and gives it to the analyzer.
    func append(_ chunk: AudioChunk) {
        do {
            input.yield(AnalyzerInput(buffer: try converter.convert(chunk.buffer)))
        } catch {
            failed.withLock { $0 = true }
        }
    }

    /// Ends the audio and waits for the last results. `true` when nothing failed.
    func finish() async -> Bool {
        input.finish()
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            try await resultsTask.value
        } catch {
            failed.withLock { $0 = true }
        }
        return !failed.withLock { $0 }
    }

    func cancel() async {
        input.finish()
        resultsTask.cancel()
        await analyzer.cancelAndFinishNow()
    }
}

/// Live transcription of both tracks.
private final class SpeechLiveSession: LiveTranscriptionSession, @unchecked Sendable {
    let lines: AsyncStream<TranscribedLine>
    private let linesContinuation: AsyncStream<TranscribedLine>.Continuation
    private let tracks: [(track: AudioTrack, transcriber: LiveTrackTranscriber)]
    private let audio: [AudioTrack: AsyncStream<AudioChunk>.Continuation]
    private let audioPumps: [Task<Void, Never>]
    private let forwarders: [Task<Void, Never>]

    init(microphone: LiveTrackTranscriber, system: LiveTrackTranscriber) {
        (lines, linesContinuation) = AsyncStream<TranscribedLine>.makeStream(bufferingPolicy: .unbounded)
        tracks = [(.microphone, microphone), (.system, system)]

        var audio: [AudioTrack: AsyncStream<AudioChunk>.Continuation] = [:]
        var audioPumps: [Task<Void, Never>] = []
        var forwarders: [Task<Void, Never>] = []
        for (track, transcriber) in tracks {
            let (stream, continuation) = AsyncStream<AudioChunk>.makeStream(bufferingPolicy: .unbounded)
            audio[track] = continuation
            // Conversion and analysis run here, never on the capture queue.
            audioPumps.append(
                Task {
                    for await chunk in stream {
                        transcriber.append(chunk)
                    }
                })
            let forward = linesContinuation
            forwarders.append(
                Task {
                    for await line in transcriber.lines {
                        forward.yield(line)
                    }
                })
        }
        self.audio = audio
        self.audioPumps = audioPumps
        self.forwarders = forwarders
    }

    func consume(_ chunk: AudioChunk, track: AudioTrack) {
        audio[track]?.yield(chunk)
    }

    func finish() async -> Bool {
        for continuation in audio.values { continuation.finish() }
        // Everything captured goes to the analyzers before they are told that the
        // audio ended; their last results end the forwarders.
        for pump in audioPumps { await pump.value }
        var complete = true
        for (_, transcriber) in tracks {
            if await !transcriber.finish() { complete = false }
        }
        for forwarder in forwarders { await forwarder.value }
        linesContinuation.finish()
        return complete
    }

    func cancel() async {
        for continuation in audio.values { continuation.finish() }
        for pump in audioPumps { pump.cancel() }
        for (_, transcriber) in tracks { await transcriber.cancel() }
        for forwarder in forwarders { forwarder.cancel() }
        linesContinuation.finish()
    }
}

enum SpeechError: Error {
    case noCompatibleFormat
}
