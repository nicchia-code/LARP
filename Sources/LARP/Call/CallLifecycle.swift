import Foundation
import Observation
import SwiftData
import os

extension Notification.Name {
    /// `call.DELETED`: posted on the main actor after a call has been deleted. The
    /// user info holds the identifier of the call under `"callID"`; read it with
    /// `Notification.callID`.
    static let callDeleted = Notification.Name("com.larp.LARP.callDeleted")
}

extension Notification {
    /// Identifier of the call a `.callDeleted` notification is about.
    var callID: UUID? {
        userInfo?["callID"] as? UUID
    }
}

/// The `call` machine (Model `transcription/call`): owns the state of every call and
/// reacts to the events that move it. The transitions are in `CallStateMachine`;
/// this class applies them and runs what each state does:
///
/// - **Recording**: audio capture and live transcription (`CallLifecycle+Recording`).
/// - **Transcribing** / **Awaiting language**: transcription from the saved audio,
///   one call at a time (`CallLifecycle+Transcription`).
/// - **Separating participants**: `ParticipantSeparating` (`CallLifecycle+Separation`).
/// - **Refining transcript**: `TranscriptRefining` (`CallLifecycle+Refinement`).
/// - **Summarising** (the `call-summary` machine, apart from the call's own state):
///   `CallLifecycle+Summary`, with its own process, alongside the refinement.
/// - **Ready** and rename/delete in every state: here.
///
/// To add a transition, add it to `CallStateMachine` and, if entering a state starts
/// work, to `enter(_:call:)`; events that come from outside call `apply(_:to:)`.
@MainActor
@Observable
final class CallLifecycle {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "call")

    /// Owned, not only reached through `context`: background work (transcription,
    /// separation, refinement) may still be ending when everything else lets go of
    /// the container, and a context whose container is gone traps on its next fetch.
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored let languages: any LanguageAvailability
    /// The language chosen in the settings, read when a recording starts.
    @ObservationIgnored let chosenLanguage: @MainActor () -> String
    @ObservationIgnored let capture: any AudioCapturing
    @ObservationIgnored let transcription: any TranscriptionService
    /// Tells the user that a recording did not start.
    @ObservationIgnored let captureFailureAlerts: any CaptureFailureAlertPresenting
    /// Ends the recorder's recording when its capture did not start, so the menu
    /// stops showing a recording that was never saved.
    @ObservationIgnored let endRecorderRecording: @MainActor () -> Void
    /// How long a failed transcription waits before it is tried again.
    @ObservationIgnored let transcriptionRetryDelay: Duration
    /// Tells the participants apart in **Separating participants**.
    @ObservationIgnored let separator: (any ParticipantSeparating)?
    /// Asks the assistant to refine transcripts in **Refining transcript**.
    @ObservationIgnored let refiner: (any TranscriptRefining)?
    /// Whether transcript refinement is on.
    @ObservationIgnored let refinementIsOn: @MainActor () -> Bool
    /// Asks the assistant to write summaries in **Summarising**, with a process of its own
    /// for every summary, so it never waits for a refinement.
    @ObservationIgnored let summarizer: (any TranscriptRefining)?
    /// Whether call summaries are on.
    @ObservationIgnored let summariesAreOn: @MainActor () -> Bool
    /// The language chosen for the summaries, read when a summary starts.
    @ObservationIgnored let summaryLanguage: @MainActor () -> SummaryLanguageChoice
    @ObservationIgnored let now: @Sendable () -> Date
    /// What the pill and the live window show of the recording in progress.
    @ObservationIgnored let live: LiveRecordingState
    /// News of the events of a call that its file in the Markdown folder follows.
    @ObservationIgnored let callChanges = EventBroadcaster<CallChange>()
    /// Tells the user that an audio file could not be imported.
    @ObservationIgnored let importFailureAlerts: any ImportFailureAlertPresenting

    // Recording (see CallLifecycle+Recording)
    @ObservationIgnored var activeRecording: ActiveRecording?
    /// The timeline of Teams speakers of the call being recorded (see `CallLifecycle+Meeting`).
    @ObservationIgnored var speakerTimeline = SpeakerTimelineBuilder()
    /// The meeting Teams shows now, read when a recording starts so that a recording that begins
    /// in a meeting already has its title, its people and its speaker. Wired by the app; absent
    /// means Teams shows nothing.
    @ObservationIgnored var teamsMeeting: @MainActor () -> TeamsReadout.Meeting? = { nil }
    /// The calendar event in progress, read when a recording starts: its title is the meeting title
    /// of a call whose Teams shows none, and its invited people are names for the participants.
    /// Wired by the app; absent means no event (the calendar is not connected or has none).
    @ObservationIgnored var calendarMeeting: @MainActor () -> CalendarMeeting? = { nil }
    /// Whether "Identifica i parlanti" is on: names from Teams are given to the participants after
    /// the separation, and offered when a participant is renamed. Wired by the app.
    @ObservationIgnored var speakerIdentificationIsOn: @MainActor () -> Bool = { true }

    // Transcription from the saved audio (see CallLifecycle+Transcription)
    @ObservationIgnored var transcriptionWorker: Task<Void, Never>?
    @ObservationIgnored var runningTranscription: (callID: UUID, task: Task<[TranscribedLine], any Error>)?
    /// Calls whose transcription failed and has not succeeded since: they show it.
    /// Observed, so the archive shows the failure as soon as it happens.
    var failedTranscriptions: Set<UUID> = []
    /// Calls waiting to be transcribed again after a failure, with the task that waits.
    @ObservationIgnored var transcriptionRetries: [UUID: Task<Void, Never>] = [:]

    // Separation of participants (see CallLifecycle+Separation)
    @ObservationIgnored var runningSeparations: [UUID: (token: Int, task: Task<Void, Never>)] = [:]
    @ObservationIgnored var separationCounter = 0

    // Refinement of transcripts (see CallLifecycle+Refinement)
    @ObservationIgnored var runningRefinements: [UUID: (token: Int, task: Task<Void, Never>)] = [:]
    @ObservationIgnored var refinementCounter = 0

    // Summaries of calls (see CallLifecycle+Summary)
    @ObservationIgnored var runningSummaries: [UUID: (token: Int, task: Task<Void, Never>)] = [:]
    @ObservationIgnored var summaryCounter = 0

    // Waveforms of calls (see CallLifecycle+Waveform)
    @ObservationIgnored var runningWaveforms: [UUID: (token: Int, task: Task<Void, Never>)] = [:]
    @ObservationIgnored var waveformCounter = 0
    @ObservationIgnored var waveformBackfill: Task<Void, Never>?

    // Audio retention (see CallLifecycle+Retention)
    /// The days the audio of a call is kept, `nil` for always. Wired by the app; absent means always.
    @ObservationIgnored var audioRetentionDays: @MainActor () -> Int? = { nil }
    /// Deletes the audio files of a call, off the main actor.
    @ObservationIgnored var audioRemover: any AudioFileRemoving = ArchiveAudioRemover()
    /// How long the app waits between two checks of the audio retention.
    @ObservationIgnored var audioRetentionInterval: Duration = .seconds(3600)
    /// The check running or last started: the next one waits for it, so none is lost.
    @ObservationIgnored var audioRetentionCheck: Task<Void, Never>?

    @ObservationIgnored private var eventTasks: [Task<Void, Never>] = []

    init(
        container: ModelContainer,
        languages: any LanguageAvailability,
        chosenLanguage: @escaping @MainActor () -> String,
        capture: any AudioCapturing,
        transcription: any TranscriptionService,
        captureFailureAlerts: any CaptureFailureAlertPresenting,
        endRecorderRecording: @escaping @MainActor () -> Void,
        transcriptionRetryDelay: Duration = .seconds(60),
        separator: (any ParticipantSeparating)? = nil,
        refiner: (any TranscriptRefining)? = nil,
        refinementIsOn: @escaping @MainActor () -> Bool = { false },
        summarizer: (any TranscriptRefining)? = nil,
        summariesAreOn: @escaping @MainActor () -> Bool = { false },
        summaryLanguage: @escaping @MainActor () -> SummaryLanguageChoice = { .default },
        now: @escaping @Sendable () -> Date = { Date() },
        live: LiveRecordingState = LiveRecordingState(),
        importFailureAlerts: any ImportFailureAlertPresenting = ImportFailureAlertPresenter()
    ) {
        self.container = container
        self.context = container.mainContext
        self.languages = languages
        self.chosenLanguage = chosenLanguage
        self.capture = capture
        self.transcription = transcription
        self.captureFailureAlerts = captureFailureAlerts
        self.endRecorderRecording = endRecorderRecording
        self.transcriptionRetryDelay = transcriptionRetryDelay
        self.separator = separator
        self.refiner = refiner
        self.refinementIsOn = refinementIsOn
        self.summarizer = summarizer
        self.summariesAreOn = summariesAreOn
        self.summaryLanguage = summaryLanguage
        self.now = now
        self.live = live
        self.importFailureAlerts = importFailureAlerts
    }

    // MARK: - Running

    /// Starts the machine: `macos.APP_LAUNCHED` first (an interrupted recording is
    /// closed before anything else), then it follows the recorder and the language
    /// readiness. Call once, at launch.
    func start(recorderEvents: AsyncStream<RecorderEvent>) {
        guard eventTasks.isEmpty else { return }
        // Subscribed now, so a language that is ready right after launch is not missed.
        let languageReady = languages.languageReady
        let launch = Task { await self.appLaunched() }
        eventTasks = [
            launch,
            Task {
                await launch.value
                for await event in recorderEvents {
                    await self.handle(event)
                }
            },
            Task {
                await launch.value
                for await language in languageReady {
                    self.languageReady(language)
                }
            },
            // `time.AUDIO_RETENTION_CHECK_DUE`: every hour while the app is open.
            Task {
                await launch.value
                while !Task.isCancelled {
                    try? await Task.sleep(for: self.audioRetentionInterval)
                    guard !Task.isCancelled else { return }
                    await self.checkAudioRetention()
                }
            },
        ]
    }

    /// `recorder.RECORDING_STARTED`, `recorder.RECORDING_STOPPED`, `user.PAUSE_RECORDING` and
    /// `user.RESUME_RECORDING`.
    func handle(_ event: RecorderEvent) async {
        switch event {
        case .started(let callAppName): await recordingStarted(callAppName: callAppName)
        case .paused: recordingPaused(true)
        case .resumed: recordingPaused(false)
        case .stopped: await recordingStopped()
        }
    }

    /// `macos.APP_LAUNCHED`.
    func appLaunched() async {
        // Before anything else: a call left in Recording ends at its last audio saved.
        await recoverInterruptedRecordings()
        for call in calls(in: [.transcribing]) {
            apply(.appLaunched(languageReady: true), to: call)
        }
        for call in calls(in: [
            .separatingParticipants, .awaitingSeparationRetry, .refiningTranscript, .awaitingRefinementRetry,
        ]) {
            apply(.appLaunched(languageReady: true), to: call)
        }
        for call in calls(summaryIn: [.writing, .awaitingRetry]) {
            applySummary(.appLaunched, to: call)
        }
        // Last: once every other work of the launch has started, the calls of an earlier version get
        // their waveform in the background.
        startWaveformBackfill()
        // And after that, the audio of the calls kept for too long is deleted.
        await checkAudioRetention()
    }

    /// `transcription-language.LANGUAGE_READY`: the calls that wait for `language`
    /// start to be transcribed.
    func languageReady(_ language: String) {
        for call in calls(in: [.awaitingLanguage]) where call.transcriptionLanguage == language {
            apply(.languageReady, to: call)
        }
    }

    // MARK: - Transitions

    /// Applies `event` to `call` following `CallStateMachine`: the new state is saved
    /// and the work of the state starts. Returns where the event led, `nil` when the
    /// state does not react to it (nothing changes).
    @discardableResult
    func apply(_ event: CallEvent, to call: Call) -> CallTransitionTarget? {
        guard let target = CallStateMachine.target(from: call.state, on: event) else { return nil }
        switch target {
        case .state(let state):
            let previous = call.state
            call.state = state
            save()
            enter(state, call: call)
            // The waveform is worked out once, when the call becomes ready.
            if state == .ready, previous != .ready { startWaveform(of: call) }
            if state == .ready { callChanges.emit(.becameReady(call.id)) }
        case .deleted:
            delete(call)
        }
        return target
    }

    /// What a state does when the call enters it.
    func enter(_ state: CallState, call: Call) {
        switch state {
        case .transcribing:
            scheduleTranscription()
        case .separatingParticipants:
            startSeparation(of: call)
        case .refiningTranscript:
            startRefinement(of: call)
        case .recording, .awaitingLanguage, .awaitingSeparationRetry, .awaitingRefinementRetry, .ready:
            break
        }
    }

    // MARK: - User actions

    /// Whether the call can be renamed or deleted: in every state but Recording.
    func canRename(_ call: Call) -> Bool {
        CallStateMachine.target(from: call.state, on: .renameCall) != nil
    }

    func canDelete(_ call: Call) -> Bool {
        CallStateMachine.target(from: call.state, on: .deleteCall) != nil
    }

    /// `user.RENAME_CALL`: the call takes the new title and stays in its state. An
    /// empty title restores the default one.
    func renameCall(_ call: Call, to title: String) {
        guard canRename(call) else { return }
        call.title = Call.normalizedName(title)
        save()
        callChanges.emit(.renamed(call.id))
    }

    /// `user.RENAME_PARTICIPANT`: the participant takes the new name everywhere in
    /// the transcript of its call, and only there. An empty name restores
    /// "Partecipante <numero>".
    func renameParticipant(_ participant: Participant, to name: String) {
        guard let call = participant.call,
            CallStateMachine.target(from: call.state, on: .renameParticipant) != nil
        else { return }
        participant.name = Call.normalizedName(name)
        save()
        callChanges.emit(.exportChanged(call.id))
    }

    /// `user.DELETE_CALL`, after the user confirmed: stops the transcription or the
    /// separation in progress and deletes the audio, the transcript (partial too),
    /// the participants and the `Recordings/<call id>/` folder. Emits `DELETED`.
    func deleteCall(_ call: Call) {
        apply(.deleteCall, to: call)
    }

    /// The effect of `DELETE_CALL`.
    private func delete(_ call: Call) {
        let id = call.id
        if runningTranscription?.callID == id {
            runningTranscription?.task.cancel()
        }
        failedTranscriptions.remove(id)
        transcriptionRetries.removeValue(forKey: id)?.cancel()
        cancelSeparation(of: id)
        cancelRefinement(of: id)
        cancelSummary(of: id)
        cancelWaveform(of: id)
        let markdownFileName = call.markdownFileName
        do {
            try ArchiveStore.delete(call, in: context)
        } catch {
            Self.logger.error("Deleting call failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NotificationCenter.default.post(name: .callDeleted, object: self, userInfo: ["callID": id])
        callChanges.emit(.deleted(id, markdownFileName: markdownFileName))
    }

    // MARK: - Store

    func save() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Saving the archive failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The calls in one of `states`, oldest first.
    func calls(in states: Set<CallState>) -> [Call] {
        let all = (try? context.fetch(FetchDescriptor<Call>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
        return all.filter { states.contains($0.state) }
    }

    /// The call with this identifier, `nil` once it has been deleted.
    func call(id: UUID) -> Call? {
        try? context.fetch(FetchDescriptor<Call>(predicate: #Predicate { $0.id == id })).first
    }
}
