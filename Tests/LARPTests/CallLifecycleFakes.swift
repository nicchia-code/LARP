import Foundation
import SwiftData
import Synchronization

@testable import LARP

/// A `LanguageAvailability` whose ready languages are controlled by the test.
final class FakeLanguages: LanguageAvailability {
    private let ready: Mutex<Set<String>>
    private let broadcaster = EventBroadcaster<String>()

    init(ready: Set<String> = ["it-IT"]) {
        self.ready = Mutex(ready)
    }

    func isReady(_ language: String) async -> Bool {
        ready.withLock { $0.contains(language) }
    }

    var languageReady: AsyncStream<String> { broadcaster.stream() }

    /// The language becomes ready: `LANGUAGE_READY`.
    func becomeReady(_ language: String) {
        _ = ready.withLock { $0.insert(language) }
        broadcaster.emit(language)
    }

    func setReady(_ languages: Set<String>) {
        ready.withLock { $0 = languages }
    }
}

/// An `AudioCapturing` that records how it was used and writes no audio.
final class FakeCapture: AudioCapturing {
    struct State {
        var startedFolders: [URL] = []
        var stopCount = 0
        var systemAudioPolicies: [SystemAudioPolicy] = []
        var sink: (any AudioBufferSink)?
        var failure: (any Error)?
    }

    private let state = Mutex(State())

    var startedFolders: [URL] { state.withLock { $0.startedFolders } }
    var stopCount: Int { state.withLock { $0.stopCount } }
    /// The `systemAudio` given to each start.
    var systemAudioPolicies: [SystemAudioPolicy] { state.withLock { $0.systemAudioPolicies } }
    var sink: (any AudioBufferSink)? { state.withLock { $0.sink } }

    func failNextStart(with error: any Error) {
        state.withLock { $0.failure = error }
    }

    func start(into folder: URL, sink: (any AudioBufferSink)?, systemAudio: SystemAudioPolicy) async throws {
        if let error = state.withLock({ state -> (any Error)? in
            defer { state.failure = nil }
            return state.failure
        }) {
            throw error
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        state.withLock {
            $0.startedFolders.append(folder)
            $0.systemAudioPolicies.append(systemAudio)
            $0.sink = sink
        }
    }

    func stop() async {
        state.withLock { $0.stopCount += 1 }
    }
}

/// A `CaptureFailureAlertPresenting` that remembers the reasons it was shown.
@MainActor
final class FakeCaptureFailureAlerts: CaptureFailureAlertPresenting {
    private(set) var reasons: [String] = []

    func present(reason: String) {
        reasons.append(reason)
    }
}

/// A live session the test feeds with lines.
final class FakeLiveSession: LiveTranscriptionSession {
    let lines: AsyncStream<TranscribedLine>
    private let continuation: AsyncStream<TranscribedLine>.Continuation
    private let completes: Bool
    private let consumed = Mutex<[AudioTrack]>([])
    private let cancelled = Mutex(false)

    /// - Parameter completes: what `finish()` answers: the whole recording was transcribed.
    init(completes: Bool = true) {
        (lines, continuation) = AsyncStream<TranscribedLine>.makeStream(bufferingPolicy: .unbounded)
        self.completes = completes
    }

    var consumedTracks: [AudioTrack] { consumed.withLock { $0 } }
    var wasCancelled: Bool { cancelled.withLock { $0 } }

    func emit(_ line: TranscribedLine) {
        continuation.yield(line)
    }

    func consume(_ chunk: AudioChunk, track: AudioTrack) {
        consumed.withLock { $0.append(track) }
    }

    func finish() async -> Bool {
        continuation.finish()
        return completes
    }

    func cancel() async {
        cancelled.withLock { $0 = true }
        continuation.finish()
    }
}

struct FakeTranscriptionFailure: Error {}

/// A `TranscriptionService` with scripted results.
final class FakeTranscription: TranscriptionService {
    struct State {
        var liveSession: FakeLiveSession?
        var liveStarts: [String] = []
        var liveFailure: (any Error)?
        /// Lines returned per speaker for every file.
        var fileLines: [SpeakerKind: [TranscribedLine]] = [:]
        /// Files wait until the task is cancelled.
        var blocksFiles = false
        var fileFailure: (any Error)?
        var transcribedFiles: [URL] = []
        var cancelledFiles = 0
        /// Order in which calls started to be transcribed (by recordings folder).
        var startedFolders: [URL] = []
    }

    let state = Mutex(State())

    func set(_ change: (inout State) -> Void) {
        state.withLock { change(&$0) }
    }

    var liveStarts: [String] { state.withLock { $0.liveStarts } }
    var transcribedFiles: [URL] { state.withLock { $0.transcribedFiles } }
    var cancelledFiles: Int { state.withLock { $0.cancelledFiles } }
    var startedFolders: [URL] { state.withLock { $0.startedFolders } }

    func startLiveSession(language: String) async throws -> any LiveTranscriptionSession {
        let (session, failure) = state.withLock { state -> (FakeLiveSession?, (any Error)?) in
            state.liveStarts.append(language)
            return (state.liveSession, state.liveFailure)
        }
        if let failure { throw failure }
        return session ?? FakeLiveSession()
    }

    func transcribeFile(at url: URL, speaker: SpeakerKind, language: String) async throws -> [TranscribedLine] {
        let (lines, blocks, failure) = state.withLock { state in
            state.transcribedFiles.append(url)
            if speaker == .me { state.startedFolders.append(url.deletingLastPathComponent()) }
            return (state.fileLines[speaker] ?? [], state.blocksFiles, state.fileFailure)
        }
        if blocks {
            do {
                try await Task.sleep(for: .seconds(120))
            } catch {
                state.withLock { $0.cancelledFiles += 1 }
                throw error
            }
        }
        if let failure { throw failure }
        return lines
    }
}

/// A `ParticipantSeparating` whose outcome is controlled by the test.
final class FakeSeparator: ParticipantSeparating {
    enum Behavior: Sendable {
        case succeed
        case fail
        /// Waits until cancelled.
        case hang
    }

    private let state = Mutex<(behavior: Behavior, started: [UUID], cancelled: Int)>((.succeed, [], 0))

    init(_ behavior: Behavior = .succeed) {
        state.withLock { $0.behavior = behavior }
    }

    var startedCallIDs: [UUID] { state.withLock { $0.started } }
    var cancelledCount: Int { state.withLock { $0.cancelled } }

    @MainActor
    func separate(_ call: Call) async throws {
        let behavior = state.withLock { state -> Behavior in
            state.started.append(call.id)
            return state.behavior
        }
        switch behavior {
        case .succeed: return
        case .fail: throw FakeTranscriptionFailure()
        case .hang:
            do {
                try await Task.sleep(for: .seconds(120))
            } catch {
                state.withLock { $0.cancelled += 1 }
                throw error
            }
        }
    }
}

/// Counts how many times the lifecycle asked the recorder to end its recording.
@MainActor
final class RecorderEndCounter {
    var count = 0
}

/// Whether transcript refinement is on, for `CallLifecycle.refinementIsOn`.
@MainActor
final class RefinementSwitch {
    var isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }
}

/// A `CallLifecycle` over an in-memory archive and fake collaborators.
@MainActor
struct CallHarness {
    let container: ModelContainer
    let languages: FakeLanguages
    let capture = FakeCapture()
    let transcription = FakeTranscription()
    let captureAlerts = FakeCaptureFailureAlerts()
    let recorderEnds = RecorderEndCounter()
    let refinement: RefinementSwitch
    let lifecycle: CallLifecycle
    private let clock: Clock

    var context: ModelContext { container.mainContext }

    /// A settable clock for `CallLifecycle.now`.
    final class Clock: Sendable {
        private let value: Mutex<Date>
        init(_ date: Date) { value = Mutex(date) }
        var date: Date {
            get { value.withLock { $0 } }
            set { value.withLock { $0 = newValue } }
        }
    }

    init(
        readyLanguages: Set<String> = ["it-IT"],
        chosenLanguage: String = "it-IT",
        separator: (any ParticipantSeparating)? = nil,
        refiner: (any TranscriptRefining)? = nil,
        refinementOn: Bool = false,
        transcriptionRetryDelay: Duration = .seconds(3600)
    ) throws {
        container = try ArchiveStore.makeContainer(inMemory: true)
        let refinement = RefinementSwitch(refinementOn)
        self.refinement = refinement
        languages = FakeLanguages(ready: readyLanguages)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        self.clock = clock
        lifecycle = CallLifecycle(
            context: container.mainContext,
            languages: languages,
            chosenLanguage: { chosenLanguage },
            capture: capture,
            transcription: transcription,
            captureFailureAlerts: captureAlerts,
            endRecorderRecording: { [recorderEnds] in recorderEnds.count += 1 },
            transcriptionRetryDelay: transcriptionRetryDelay,
            separator: separator,
            refiner: refiner,
            refinementIsOn: { [refinement] in refinement.isOn },
            now: { clock.date }
        )
    }

    func advanceClock(by seconds: TimeInterval) {
        clock.date = clock.date.addingTimeInterval(seconds)
    }

    /// Inserts a call in `state` with an audio file per track.
    @discardableResult
    func insertCall(
        _ state: CallState,
        title: String? = nil,
        language: String = "it-IT",
        startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        withAudio: Bool = true
    ) throws -> Call {
        let call = Call(title: title, startedAt: startedAt, transcriptionLanguage: language, state: state)
        context.insert(call)
        try context.save()
        if withAudio {
            try FileManager.default.createDirectory(at: call.recordingsFolderURL, withIntermediateDirectories: true)
            try Data("audio".utf8).write(to: call.micAudioURL)
            try Data("audio".utf8).write(to: call.systemAudioURL)
        }
        return call
    }

    func allCalls() throws -> [Call] {
        try context.fetch(FetchDescriptor<Call>())
    }

    /// Removes the recordings folders the test created.
    func cleanUp() {
        for call in (try? allCalls()) ?? [] {
            try? FileManager.default.removeItem(at: call.recordingsFolderURL)
        }
        for url in capture.startedFolders {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Waits, up to a few seconds, until `condition` holds.
    func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<400 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
