import Foundation
import Observation

/// The choices of the summary language: "Come la call", "Italiano" or "English".
enum SummaryLanguageChoice: String, CaseIterable, Identifiable, Sendable {
    /// The transcription language of the call: English when the call is in English, otherwise
    /// Italian. Stored as `call`.
    case sameAsCall = "call"
    case italian = "it-IT"
    case english = "en-US"

    static let `default` = SummaryLanguageChoice.sameAsCall

    var id: String { rawValue }

    /// The text of the choice, a key of the String Catalog.
    var title: String {
        switch self {
        case .sameAsCall: "Come la call"
        case .italian: "Italiano"
        case .english: "English"
        }
    }

    /// The language the summary of a call is asked in, as a locale identifier (`it-IT` or
    /// `en-US`), given the transcription language of the call: "Italiano" and "English" ask for
    /// their language whatever the language of the call.
    func language(forCallLanguage callLanguage: String) -> String {
        switch self {
        case .italian: TranscriptionLanguage.italian.rawValue
        case .english: TranscriptionLanguage.english.rawValue
        case .sameAsCall:
            Locale(identifier: callLanguage).language.languageCode?.identifier == "en"
                ? TranscriptionLanguage.english.rawValue : TranscriptionLanguage.italian.rawValue
        }
    }
}

/// The `summary-language` machine: the language in which omp writes the summaries.
///
/// The choice lives in `UserDefaults` and is "Come la call" unless another one was saved (an
/// unknown stored value reads as "Come la call"). A new choice applies to the summaries written
/// after it; the language asked is stored with each summary, so a summary already written keeps
/// its own.
@MainActor
@Observable
final class SummaryLanguageController {
    /// The controller shared by the app: the settings page and the call lifecycle read the same
    /// instance.
    static let shared = SummaryLanguageController()

    /// States of the `summary-language` machine: **Chosen**, with the current choice.
    private(set) var choice: SummaryLanguageChoice

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choice =
            defaults.string(forKey: SettingsKey.summaryLanguage)
            .flatMap(SummaryLanguageChoice.init(rawValue:)) ?? .default
    }

    // MARK: Events

    /// `user.CHOOSE_SUMMARY_LANGUAGE`: Chosen → Chosen; the choice is saved.
    func choose(_ newChoice: SummaryLanguageChoice) {
        choice = newChoice
        defaults.set(newChoice.rawValue, forKey: SettingsKey.summaryLanguage)
    }
}
