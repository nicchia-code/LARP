import AVFoundation
import Foundation
import Speech
import Testing

@testable import LARP

/// Runs the real `SpeechAnalyzer` on speech synthesized with `say`. Needs the
/// speech model of en-US installed, so it is skipped on CI.
@Suite("Speech transcription service", .serialized, .tags(.requiresHardware))
struct SpeechTranscriptionServiceTests {
    private static let language = "en-US"
    private static let sentence = "Hello everyone. Today we review the budget for the next quarter."

    /// The sentence as a mono track in the format of the capture, and its audio.
    private func synthesizedTrack() async throws -> (url: URL, audio: AVAudioPCMBuffer) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "larp-speech-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let aiff = directory.appending(path: "speech.aiff")
        let say = Process()
        say.executableURL = URL(filePath: "/usr/bin/say")
        say.arguments = ["-v", "Samantha", "-o", aiff.path, Self.sentence]
        try say.run()
        say.waitUntilExit()
        try #require(say.terminationStatus == 0, "say failed")

        let source = try AVAudioFile(forReading: aiff)
        let input = try #require(AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: AVAudioFrameCount(source.length)))
        try source.read(into: input)
        let audio = try BufferConverter(target: AudioFormats.storage).convert(input)

        let url = directory.appending(path: AudioTrack.microphone.fileName)
        let writer = try AACFileWriter(url: url)
        try writer.write(audio)
        writer.close()
        return (url, audio)
    }

    private func installed() async -> Bool {
        let wanted = Locale(identifier: Self.language).identifier(.bcp47)
        return await SpeechTranscriber.installedLocales.contains { $0.identifier(.bcp47) == wanted }
    }

    @Test("a saved track is transcribed into final lines with times")
    func transcribesFile() async throws {
        try #require(await installed(), "speech model not installed")
        let (url, _) = try await synthesizedTrack()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let lines = try await SpeechTranscriptionService().transcribeFile(at: url, speaker: .me, language: Self.language)

        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.speaker == .me && $0.end >= $0.start && $0.start >= 0 })
        #expect(lines.map(\.text).joined(separator: " ").localizedCaseInsensitiveContains("budget"))
    }

    @Test("audio fed while recording is transcribed live")
    func transcribesLive() async throws {
        try #require(await installed(), "speech model not installed")
        let (url, audio) = try await synthesizedTrack()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let session = try await SpeechTranscriptionService().startLiveSession(language: Self.language)
        // One second at a time, as the capture does.
        let chunk = Int(AudioFormats.storageSampleRate)
        var position = 0
        while position < Int(audio.frameLength) {
            let count = min(chunk, Int(audio.frameLength) - position)
            let piece = try #require(AVAudioPCMBuffer(pcmFormat: audio.format, frameCapacity: AVAudioFrameCount(count)))
            piece.frameLength = AVAudioFrameCount(count)
            piece.floatChannelData![0].update(from: audio.floatChannelData![0] + position, count: count)
            session.consume(AudioChunk(buffer: piece), track: .microphone)
            position += count
        }
        let complete = await session.finish()
        var lines: [TranscribedLine] = []
        for await line in session.lines { lines.append(line) }

        #expect(complete)
        #expect(lines.allSatisfy { $0.speaker == .me })
        #expect(lines.map(\.text).joined(separator: " ").localizedCaseInsensitiveContains("budget"))
    }
}
