import Foundation

extension CallState {
    /// Progress shown for a call that is not ready; `nil` once it is ready. In the interface language.
    var statusLabel: String? {
        statusLabel(language: .current)
    }

    func statusLabel(language: AppLanguage) -> String? {
        switch self {
        case .recording: L10n.string("In registrazione", language: language)
        case .awaitingLanguage: L10n.string("In attesa della lingua", language: language)
        case .transcribing: L10n.string("Trascrizione…", language: language)
        case .separatingParticipants: L10n.string("Separazione voci…", language: language)
        case .awaitingSeparationRetry: L10n.string("Voci da separare", language: language)
        case .refiningTranscript: L10n.string("Rifinitura testo…", language: language)
        case .awaitingRefinementRetry: L10n.string("Testo da rifinire", language: language)
        case .ready: nil
        }
    }
}

extension SummaryState {
    /// Progress shown for a Ready call whose summary is not done; `nil` when it has no summary
    /// being written or waiting, or holds it. In the interface language.
    var statusLabel: String? {
        statusLabel(language: .current)
    }

    func statusLabel(language: AppLanguage) -> String? {
        switch self {
        case .writing: L10n.string("Sintesi…", language: language)
        case .awaitingRetry: L10n.string("Sintesi da fare", language: language)
        case .none, .written: nil
        }
    }
}
