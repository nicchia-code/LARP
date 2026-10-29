import Foundation

/// Events the `call-summary` machine reacts to. Events with a guard carry the facts the
/// guard needs.
enum SummaryEvent: Equatable, Sendable {
    /// `call.PARTICIPANTS_SEPARATED`. `summariesOn`: call summaries are on. `hasLines`:
    /// the transcript has at least one line.
    case participantsSeparated(summariesOn: Bool, hasLines: Bool)
    /// `user.SUMMARIZE_CALL`. `participantsTold`: the participants have been told apart.
    case summarizeCall(summariesOn: Bool, hasLines: Bool, participantsTold: Bool)
    /// `call-summary.SUMMARY_WRITTEN`
    case summaryWritten
    /// `call-summary.SUMMARY_FAILED`
    case summaryFailed
    /// `user.TURN_OFF_SUMMARY`. `hadSummary`: the call has a summary written before.
    case turnOffSummary(hadSummary: Bool)
    /// `macos.APP_LAUNCHED`
    case appLaunched
    /// `macos.NETWORK_AVAILABLE`
    case networkAvailable
}

/// The transition table of the `call-summary` machine (Model `transcription/call-summary`),
/// inside **Kept**. Pure: it only says where an event leads; `CallLifecycle` performs the
/// effects. A state that does not react to an event has no entry (`nil`). `call.DELETED`
/// is the `call` machine's.
enum CallSummaryStateMachine {
    static func target(from state: SummaryState, on event: SummaryEvent) -> SummaryState? {
        switch (state, event) {
        // No summary
        case (.none, .participantsSeparated(let summariesOn, let hasLines)):
            return summariesOn && hasLines ? .writing : nil
        case (.none, .summarizeCall(let summariesOn, let hasLines, let participantsTold)):
            return summariesOn && hasLines && participantsTold ? .writing : nil

        // Summarising
        case (.writing, .summaryWritten):
            return .written
        case (.writing, .summaryFailed):
            return .awaitingRetry
        case (.writing, .turnOffSummary(let hadSummary)):
            return hadSummary ? .written : SummaryState.none
        case (.writing, .appLaunched):
            return .writing

        // Awaiting summary retry
        case (.awaitingRetry, .networkAvailable), (.awaitingRetry, .appLaunched):
            return .writing
        case (.awaitingRetry, .summarizeCall(_, let hasLines, _)):
            return hasLines ? .writing : nil
        case (.awaitingRetry, .turnOffSummary(let hadSummary)):
            return hadSummary ? .written : SummaryState.none

        // Summarised
        case (.written, .summarizeCall(let summariesOn, let hasLines, _)):
            return summariesOn && hasLines ? .writing : nil

        default:
            return nil
        }
    }
}
