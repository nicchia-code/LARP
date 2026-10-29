import AVFoundation
import Foundation
import Testing

@testable import LARP

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<1000 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition not reached in time", sourceLocation: sourceLocation)
}

@Suite("EngineTrackPlayer", .serialized)
@MainActor
struct EngineTrackPlayerTests {
    /// Writes a mono 16 kHz CAF file of silence, `seconds` long.
    private func makeAudioFile(seconds: Double, in folder: URL, name: String) throws -> URL {
        let url = folder.appending(path: name)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * 16_000)))
        buffer.frameLength = buffer.frameCapacity
        try file.write(from: buffer)
        return url
    }

    private func makeFolder() throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "larp-playback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test(
        "the duration is the one of the longest readable track; missing files are skipped",
        .tags(.requiresHardware))
    func durationOfLongestTrack() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let mic = try makeAudioFile(seconds: 1, in: folder, name: "mic.caf")
        let system = try makeAudioFile(seconds: 2, in: folder, name: "system.caf")
        let missing = folder.appending(path: "missing.caf")

        #expect(abs(EngineTrackPlayer(urls: [mic, system]).duration - 2) < 0.01)
        #expect(abs(EngineTrackPlayer(urls: [mic, missing]).duration - 1) < 0.01)
        #expect(EngineTrackPlayer(urls: [missing]).duration == 0)
    }

    @Test("both tracks play to the end, then the player reports it once", .tags(.requiresHardware))
    func playsToTheEnd() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let mic = try makeAudioFile(seconds: 0.4, in: folder, name: "mic.caf")
        let system = try makeAudioFile(seconds: 0.6, in: folder, name: "system.caf")
        let player = EngineTrackPlayer(urls: [mic, system])

        var finished = 0
        player.start(at: 0.1) { finished += 1 }
        await waitUntil { finished > 0 }
        #expect(finished == 1)
    }

    @Test("starting past the end of the audio finishes at once", .tags(.requiresHardware))
    func startingPastTheEnd() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let mic = try makeAudioFile(seconds: 0.3, in: folder, name: "mic.caf")
        let player = EngineTrackPlayer(urls: [mic])

        var finished = 0
        player.start(at: 5) { finished += 1 }
        #expect(finished == 1)
    }

    @Test(
        "a change of the audio output while playing goes on from the time reached, until the end",
        .tags(.requiresHardware))
    func outputChangeWhilePlaying() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let mic = try makeAudioFile(seconds: 0.8, in: folder, name: "mic.caf")
        let system = try makeAudioFile(seconds: 1, in: folder, name: "system.caf")
        let player = EngineTrackPlayer(urls: [mic, system])

        var finished = 0
        var interrupted = 0
        player.onInterrupted = { _ in interrupted += 1 }
        player.start(at: 0.3) { finished += 1 }
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: player.engine)
        #expect(player.currentTime >= 0.3)
        await waitUntil { finished > 0 }
        #expect(finished == 1)
        #expect(interrupted == 0)
    }

    @Test("a change of the audio output while stopped keeps the player stopped", .tags(.requiresHardware))
    func outputChangeWhileStopped() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let mic = try makeAudioFile(seconds: 0.3, in: folder, name: "mic.caf")
        let player = EngineTrackPlayer(urls: [mic])

        var interrupted = 0
        player.onInterrupted = { _ in interrupted += 1 }
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: player.engine)
        #expect(!player.engine.isRunning)
        #expect(interrupted == 0)
        player.unload()
    }
}
