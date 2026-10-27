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
