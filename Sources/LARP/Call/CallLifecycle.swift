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
/// - **Ready** and rename/delete in every state: here.
///
/// To add a transition, add it to `CallStateMachine` and, if entering a state starts
/// work, to `enter(_:call:)`; events that come from outside call `apply(_:to:)`.
@MainActor
@Observable
final class CallLifecycle {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "call")

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
    @ObservationIgnored let now: @Sendable () -> Date

    // Recording (see CallLifecycle+Recording)
    @ObservationIgnored var activeRecording: ActiveRecording?

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

    @ObservationIgnored private var eventTasks: [Task<Void, Never>] = []

    init(
        context: ModelContext,
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
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.context = context
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
        self.now = now
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
        ]
    }

    /// `recorder.RECORDING_STARTED` and `recorder.RECORDING_STOPPED`.
    func handle(_ event: RecorderEvent) async {
        switch event {
        case .started(let callAppName): await recordingStarted(callAppName: callAppName)
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
            call.state = state
            save()
            enter(state, call: call)
        case .deleted:
            delete(call)
        }
        return target
    }

    /// What a state does when the call enters it.
    private func enter(_ state: CallState, call: Call) {
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
        do {
            try ArchiveStore.delete(call, in: context)
        } catch {
            Self.logger.error("Deleting call failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NotificationCenter.default.post(name: .callDeleted, object: self, userInfo: ["callID": id])
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
