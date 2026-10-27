import Foundation

/// Events the `call` machine reacts to. Events with a guard carry the facts the
/// guard needs.
enum CallEvent: Equatable, Sendable {
    /// `recorder.RECORDING_STOPPED`. `fullyTranscribedLive`: the whole recording was
    /// transcribed live. `languageReady`: the chosen language is ready.
    case recordingStopped(fullyTranscribedLive: Bool, languageReady: Bool)
    /// `macos.APP_LAUNCHED`. `languageReady`: the chosen language is ready.
    case appLaunched(languageReady: Bool)
    /// `transcription-language.LANGUAGE_READY`
    case languageReady
    /// `call.TRANSCRIPTION_COMPLETED`
    case transcriptionCompleted
    /// `call.PARTICIPANTS_SEPARATED`. `refinementOn`: transcript refinement is on.
    case participantsSeparated(refinementOn: Bool)
    /// `call.SEPARATION_FAILED`
    case separationFailed
    /// `call.TRANSCRIPT_REFINED`
    case transcriptRefined
    /// `call.REFINEMENT_FAILED`
    case refinementFailed
    /// `user.TURN_OFF_REFINEMENT`
    case turnOffRefinement
    /// `user.REFINE_TRANSCRIPT`. `refinementOn`: transcript refinement is on.
    case refineTranscript(refinementOn: Bool)
    /// `user.RESTORE_TRANSCRIPT`. `refined`: the transcript has been refined.
    case restoreTranscript(refined: Bool)
    /// `macos.NETWORK_AVAILABLE`
    case networkAvailable
    /// `user.RENAME_CALL`
    case renameCall
    /// `user.RENAME_PARTICIPANT`
    case renameParticipant
    /// `user.DELETE_CALL`
    case deleteCall
}

/// Where a transition leads: another state, or the end of the call (**Deleted**,
/// final: the call no longer exists, so it has no `CallState`).
enum CallTransitionTarget: Equatable, Sendable {
    case state(CallState)
    case deleted
}

/// The transition table of the `call` machine (Model `transcription/call`).
/// Pure: it only says where an event leads; `CallLifecycle` performs the effects.
/// A state that does not react to an event has no entry (`nil`).
enum CallStateMachine {
    static func target(from state: CallState, on event: CallEvent) -> CallTransitionTarget? {
        switch (state, event) {
        // Recording
        case (.recording, .recordingStopped(let fullyTranscribedLive, let languageReady)):
            if fullyTranscribedLive { return .state(.separatingParticipants) }
            return .state(languageReady ? .transcribing : .awaitingLanguage)
        case (.recording, .appLaunched(let languageReady)):
            return .state(languageReady ? .transcribing : .awaitingLanguage)

        // Awaiting language
        case (.awaitingLanguage, .languageReady):
            return .state(.transcribing)

        // Transcribing
        case (.transcribing, .transcriptionCompleted):
            return .state(.separatingParticipants)
        case (.transcribing, .appLaunched):
            return .state(.transcribing)

        // Separating participants
        case (.separatingParticipants, .participantsSeparated(let refinementOn)):
            return .state(refinementOn ? .refiningTranscript : .ready)
        case (.separatingParticipants, .separationFailed):
            return .state(.awaitingSeparationRetry)
        case (.separatingParticipants, .appLaunched):
            return .state(.separatingParticipants)

        // Awaiting separation retry
        case (.awaitingSeparationRetry, .networkAvailable),
            (.awaitingSeparationRetry, .appLaunched):
            return .state(.separatingParticipants)

        // Refining transcript
        case (.refiningTranscript, .transcriptRefined), (.refiningTranscript, .turnOffRefinement):
            return .state(.ready)
        case (.refiningTranscript, .refinementFailed):
            return .state(.awaitingRefinementRetry)
        case (.refiningTranscript, .appLaunched):
            return .state(.refiningTranscript)

        // Awaiting refinement retry
        case (.awaitingRefinementRetry, .networkAvailable),
            (.awaitingRefinementRetry, .appLaunched),
            (.awaitingRefinementRetry, .refineTranscript):
            return .state(.refiningTranscript)
        case (.awaitingRefinementRetry, .turnOffRefinement):
            return .state(.ready)

        // Ready
        case (.ready, .renameParticipant):
            return .state(.ready)
        case (.ready, .refineTranscript(let refinementOn)):
            return refinementOn ? .state(.refiningTranscript) : nil
        case (.ready, .restoreTranscript(let refined)):
            return refined ? .state(.ready) : nil

        // Rename and delete: every state but Recording, the same state for a rename
        case (.recording, .renameCall), (.recording, .deleteCall):
            return nil
        case (_, .renameCall):
            return .state(state)
        case (_, .deleteCall):
            return .deleted

        default:
            return nil
        }
    }
}
