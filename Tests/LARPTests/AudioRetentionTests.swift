import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

/// An `AudioFileRemoving` that fails while the test says so, and removes the files like the real one.
private final class FlakyRemover: AudioFileRemoving {
    private let failing = Mutex(false)
    private let removed = Mutex<[URL]>([])

    var isFailing: Bool {
        get { failing.withLock { $0 } }
        set { failing.withLock { $0 = newValue } }
    }

    var removedURLs: [URL] { removed.withLock { $0 } }

    func removeFiles(at urls: [URL]) async throws {
        if isFailing { throw FakeTranscriptionFailure() }
        try await ArchiveAudioRemover().removeFiles(at: urls)
        removed.withLock { $0.append(contentsOf: urls) }
    }
}

private let day: TimeInterval = 24 * 60 * 60
/// The time of `CallHarness`'s clock.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// The machine `audio-retention`, on the call side: which calls lose their audio, and what stays.
@Suite("Audio retention", .serialized)
@MainActor
struct AudioRetentionTests {
    private func makeHarness(days: Int?) throws -> CallHarness {
        let harness = try CallHarness()
        harness.lifecycle.audioRetentionDays = { days }
        return harness
    }

    private func startedDaysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * day)
    }

    private func audioExists(of call: Call) -> (mic: Bool, system: Bool) {
        (
            FileManager.default.fileExists(atPath: call.micAudioURL.path),
            FileManager.default.fileExists(atPath: call.systemAudioURL.path)
        )
    }

    @Test("a ready call started more than the chosen days ago loses its two audio files and keeps the rest")
    func removesOldAudio() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(31))
        let other = call.recordingsFolderURL.appending(path: "notes.txt")
        try Data("keep".utf8).write(to: other)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "ciao"))
        call.bookmarks.append(Bookmark(time: 3))
        call.waveform = [WaveformBar(level: 0.5, speaker: .me)]
        try harness.context.save()

        await harness.lifecycle.checkAudioRetention()

        #expect(audioExists(of: call) == (false, false))
        #expect(FileManager.default.fileExists(atPath: other.path))
        #expect(call.audioRemovedAfterDays == 30)
        #expect(call.state == .ready)
        #expect(call.lines.count == 1)
        #expect(call.bookmarks.count == 1)
        #expect(call.waveform?.count == 1)
    }

    @Test("a day is 24 hours from the start: a call exactly at the limit keeps its audio")
    func exactlyAtTheLimit() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let atLimit = try harness.insertCall(.ready, startedAt: startedDaysAgo(30))
        let justOver = try harness.insertCall(.ready, startedAt: startedDaysAgo(30).addingTimeInterval(-1))

        await harness.lifecycle.checkAudioRetention()

        #expect(audioExists(of: atLimit) == (true, true))
        #expect(atLimit.audioRemovedAfterDays == nil)
        #expect(audioExists(of: justOver) == (false, false))
    }

    @Test("a more recent call keeps its audio")
    func recentCallKeepsAudio() async throws {
        let harness = try makeHarness(days: 90)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(60))

        await harness.lifecycle.checkAudioRetention()

        #expect(audioExists(of: call) == (true, true))
        #expect(call.audioRemovedAfterDays == nil)
    }

    @Test("with the audio kept always nothing is deleted")
    func keepForever() async throws {
        let harness = try makeHarness(days: nil)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(1000))

        await harness.lifecycle.checkAudioRetention()

        #expect(audioExists(of: call) == (true, true))
        #expect(call.audioRemovedAfterDays == nil)
    }

    @Test("only ready calls are looked at")
    func onlyReadyCalls() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let states: [CallState] = [.transcribing, .awaitingLanguage, .refiningTranscript, .awaitingRefinementRetry]
        var calls: [Call] = []
        for state in states { calls.append(try harness.insertCall(state, startedAt: startedDaysAgo(100))) }

        await harness.lifecycle.checkAudioRetention()

        for call in calls {
            #expect(audioExists(of: call) == (true, true))
            #expect(call.audioRemovedAfterDays == nil)
        }
    }

    @Test("a call whose summary is being written is skipped, and removed at the next check")
    func summaryBeingWritten() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(40))
        call.summaryState = .writing
        try harness.context.save()

        await harness.lifecycle.checkAudioRetention()
        #expect(audioExists(of: call) == (true, true))
        #expect(call.audioRemovedAfterDays == nil)

        call.summaryState = .written
        await harness.lifecycle.checkAudioRetention()
        #expect(audioExists(of: call) == (false, false))
        #expect(call.audioRemovedAfterDays == 30)
    }

    @Test("a call that cannot be cleared is not marked and is tried again at the next check")
    func failedRemovalIsRetried() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let remover = FlakyRemover()
        remover.isFailing = true
        harness.lifecycle.audioRemover = remover
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(40))

        await harness.lifecycle.checkAudioRetention()
        #expect(call.audioRemovedAfterDays == nil)
        #expect(audioExists(of: call) == (true, true))

        remover.isFailing = false
        await harness.lifecycle.checkAudioRetention()
        #expect(call.audioRemovedAfterDays == 30)
        #expect(remover.removedURLs.count == 2)
    }

    @Test("the days kept are the ones in force when the audio was removed, and later limits leave it alone")
    func daysInForceAreKept() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let days = Mutex<Int?>(90)
        harness.lifecycle.audioRetentionDays = { days.withLock { $0 } }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(100))

        await harness.lifecycle.checkAudioRetention()
        #expect(call.audioRemovedAfterDays == 90)

        days.withLock { $0 = 30 }
        await harness.lifecycle.checkAudioRetention()
        #expect(call.audioRemovedAfterDays == 90)
    }

    @Test("a call without audio files is not marked")
    func noFiles() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(100), withAudio: false)

        await harness.lifecycle.checkAudioRetention()

        #expect(call.audioRemovedAfterDays == nil)
    }

    @Test("an imported call, which has only its system track, loses that one")
    func importedCall() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(100), withAudio: false)
        try FileManager.default.createDirectory(at: call.recordingsFolderURL, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: call.systemAudioURL)

        await harness.lifecycle.checkAudioRetention()

        #expect(audioExists(of: call) == (false, false))
        #expect(call.audioRemovedAfterDays == 30)
    }

    @Test("macos.APP_LAUNCHED checks the calls once the other work of the launch has started")
    func launchChecks() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(40))

        await harness.lifecycle.appLaunched()

        #expect(call.audioRemovedAfterDays == 30)
    }

    @Test("time.AUDIO_RETENTION_CHECK_DUE: the timer of the app checks again, after the launch")
    func timerChecks() async throws {
        let harness = try makeHarness(days: 30)
        defer { harness.cleanUp() }
        harness.lifecycle.audioRetentionInterval = .milliseconds(20)
        let events = AsyncStream<RecorderEvent>.makeStream()
        harness.lifecycle.start(recorderEvents: events.stream)
        // A call that becomes old enough after the launch.
        let call = try harness.insertCall(.ready, startedAt: startedDaysAgo(40))

        #expect(await harness.eventually { call.audioRemovedAfterDays == 30 })
        // The timer goes on as long as the app runs: with the audio kept always it has nothing to do.
        harness.lifecycle.audioRetentionDays = { nil }
        events.continuation.finish()
    }
}

/// The settings side of the machine: what is saved, and what the call layer is told.
@Suite("Audio retention choice", .serialized)
@MainActor
struct AudioRetentionChoiceTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
    }

    @Test("the audio is kept always unless a limit was chosen; any other saved value reads as always")
    func initialChoice() {
        let defaults = makeDefaults()
        #expect(AudioRetentionController(defaults: defaults).retention == .forever)
        defaults.set(30, forKey: SettingsKey.audioRetentionDays)
        #expect(AudioRetentionController(defaults: defaults).retention == .thirtyDays)
        defaults.set(90, forKey: SettingsKey.audioRetentionDays)
        #expect(AudioRetentionController(defaults: defaults).retention == .ninetyDays)
        defaults.set(45, forKey: SettingsKey.audioRetentionDays)
        #expect(AudioRetentionController(defaults: defaults).retention == .forever)
    }

    @Test("choosing a limit saves it and tells the call layer; choosing the same one does nothing")
    func choosingALimit() async {
        let defaults = makeDefaults()
        let controller = AudioRetentionController(defaults: defaults)
        var events = controller.limitEvents.makeAsyncIterator()

        controller.choose(.thirtyDays)
        #expect(controller.retention == .thirtyDays)
        #expect(defaults.integer(forKey: SettingsKey.audioRetentionDays) == 30)
        #expect(await events.next() == 30)

        controller.choose(.thirtyDays)
        controller.choose(.ninetyDays)
        #expect(defaults.integer(forKey: SettingsKey.audioRetentionDays) == 90)
        #expect(await events.next() == 90)
    }

    @Test("choosing Sempre saves it and deletes nothing")
    func choosingAlways() async {
        let defaults = makeDefaults()
        defaults.set(30, forKey: SettingsKey.audioRetentionDays)
        let controller = AudioRetentionController(defaults: defaults)
        var events = controller.limitEvents.makeAsyncIterator()

        controller.choose(.forever)
        #expect(controller.retention == .forever)
        #expect(defaults.object(forKey: SettingsKey.audioRetentionDays) == nil)
        controller.choose(.forever)
        controller.choose(.ninetyDays)
        // The first thing told is the 90 days: choosing Sempre told nothing.
        #expect(await events.next() == 90)
    }
}

@MainActor
private final class LoadedPlayer: TrackPlayer {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var speed: Double = 1
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    private(set) var starts: [TimeInterval] = []
    private(set) var unloads = 0

    init(duration: TimeInterval) { self.duration = duration }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) { starts.append(time) }
    func stop() {}
    func unload() { unloads += 1 }
}

/// A call whose audio the retention removed cannot be played.
@Suite("Playback after the audio retention", .serialized)
@MainActor
struct RemovedAudioPlaybackTests {
    private func makeController(duration: TimeInterval = 60) -> (PlaybackController, LoadedPlayer) {
        let player = LoadedPlayer(duration: duration)
        let options = PlaybackOptions(defaults: UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!)
        return (PlaybackController(options: options, makePlayer: { _ in player }), player)
    }

    @Test("a call with its audio removed has nothing to play, and no way to start it")
    func nothingToPlay() {
        let (controller, player) = makeController()
        let call = Call(duration: 120, transcriptionLanguage: "it-IT", state: .ready)
        call.audioRemovedAfterDays = 30
        controller.show(call)

        #expect(!controller.canPlay)
        #expect(controller.audioRemovedAfterDays == 30)
        #expect(controller.duration == 120)
        controller.play()
        controller.play(fromSentenceStart: 5)
        controller.selectBookmark(at: 8, of: call)
        #expect(controller.state == .stopped)
        #expect(player.starts.isEmpty)
    }

    @Test("audio removed while the call is shown stops what plays and unloads it")
    func removedWhileShown() {
        let (controller, player) = makeController()
        let call = Call(duration: 120, transcriptionLanguage: "it-IT", state: .ready)
        controller.show(call)
        controller.play()
        #expect(controller.state == .playing)

        call.audioRemovedAfterDays = 90
        controller.show(call)

        #expect(controller.state == .stopped)
        #expect(!controller.canPlay)
        #expect(controller.audioRemovedAfterDays == 90)
        #expect(player.unloads == 1)
    }

    @Test("another call is not marked as removed")
    func otherCall() {
        let (controller, _) = makeController()
        let removed = Call(duration: 120, transcriptionLanguage: "it-IT", state: .ready)
        removed.audioRemovedAfterDays = 30
        controller.show(removed)
        controller.show(Call(duration: 60, transcriptionLanguage: "it-IT", state: .ready))
        #expect(controller.audioRemovedAfterDays == nil)
        #expect(controller.canPlay)
    }
}
