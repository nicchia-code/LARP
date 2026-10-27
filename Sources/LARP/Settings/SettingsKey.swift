import Foundation

/// `UserDefaults` keys of the app settings. Use them with `@AppStorage` or
/// `UserDefaults.standard`.
enum SettingsKey {
    /// Language used to transcribe calls (locale identifier, e.g. `it-IT`).
    static let transcriptionLanguage = "settings.transcriptionLanguage"
    /// Whether transcripts are refined by omp (`Bool`, off by default).
    static let transcriptRefinement = "settings.transcriptRefinement"
    /// Whether the app starts at login (`Bool`).
    static let launchAtLogin = "settings.launchAtLogin"
}
