import Foundation

/// The texts the settings show for the state of the speech model and of omp. Shared by the settings
/// page and the welcome window.
enum SettingsText {
    /// The state of the speech model of the chosen language.
    static func languageStatus(
        _ status: TranscriptionLanguageController.Status, language: AppLanguage = .current
    ) -> String {
        switch status {
        case .checking: L10n.string("Verifica in corso…", language: language)
        case .downloading: L10n.string("Download in corso…", language: language)
        case .missing: L10n.string("Non disponibile, nuovo tentativo appena possibile", language: language)
        case .ready: L10n.string("Pronta", language: language)
        }
    }

    /// The state of omp shown below an omp switch that is on; none while omp is not needed.
    static func assistantStatus(
        _ state: AssistantStatusController.State, language: AppLanguage = .current
    ) -> String? {
        switch state {
        case .notNeeded: nil
        case .checking: L10n.string("Verifica in corso…", language: language)
        case .assistantReady: L10n.string("omp pronto", language: language)
        case .assistantMissing: L10n.string("omp non trovato", language: language)
        }
    }
}
