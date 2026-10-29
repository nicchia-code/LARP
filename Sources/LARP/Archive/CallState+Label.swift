import Foundation

extension CallState {
    /// Progress shown for a call that is not ready; `nil` once it is ready.
    var statusLabel: String? {
        switch self {
        case .recording: "In registrazione"
        case .awaitingLanguage: "In attesa della lingua"
        case .transcribing: "Trascrizione…"
        case .separatingParticipants: "Separazione voci…"
        case .awaitingSeparationRetry: "Voci da separare"
        case .refiningTranscript: "Rifinitura testo…"
        case .awaitingRefinementRetry: "Testo da rifinire"
        case .ready: nil
        }
    }
}

extension SummaryState {
    /// Progress shown for a Ready call whose summary is not done; `nil` when it has no summary
    /// being written or waiting, or holds it.
    var statusLabel: String? {
        switch self {
        case .writing: "Sintesi…"
        case .awaitingRetry: "Sintesi da fare"
        case .none, .written: nil
        }
    }
}
