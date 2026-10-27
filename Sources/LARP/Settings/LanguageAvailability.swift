import Foundation
import Speech

/// What the rest of the app needs to know about the transcription language:
/// whether the speech model of a language is installed, and when one becomes
/// installed (the `LANGUAGE_READY` event that unlocks calls waiting for it).
/// Replaceable in tests.
protocol LanguageAvailability: Sendable {
    /// `true` when the speech model of `language` (a locale identifier such as
    /// `it-IT` or `en-US`) is installed.
    func isReady(_ language: String) async -> Bool

    /// A new stream that yields the language code every time the speech model
    /// of the chosen language becomes installed (`LANGUAGE_READY`). Each
    /// access returns an independent stream, so several consumers can listen
    /// at the same time.
    var languageReady: AsyncStream<String> { get }
}

/// Installed speech models and their installation. Replaceable in tests.
protocol SpeechModels: Sendable {
    /// `true` when the speech model of `language` is installed.
    func isInstalled(_ language: String) async -> Bool

    /// Downloads and installs the speech model of `language`; returns when it
    /// is installed, throws when the download fails.
    func install(_ language: String) async throws
}

/// The transcription languages the user can choose from.
enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case italian = "it-IT"
    case english = "en-US"

    static let `default` = TranscriptionLanguage.italian

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .italian: "Italiano"
        case .english: "English"
        }
    }
}

/// `SpeechModels` backed by Apple's speech models:
/// `SpeechTranscriber.installedLocales` and `AssetInventory`.
struct AppleSpeechModels: SpeechModels {
    func isInstalled(_ language: String) async -> Bool {
        let wanted = Locale(identifier: language).identifier(.bcp47)
        return await SpeechTranscriber.installedLocales.contains { $0.identifier(.bcp47) == wanted }
    }

    func install(_ language: String) async throws {
        let transcriber = Self.transcriber(for: language)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard await isInstalled(language) else {
            throw LanguageInstallError.notInstalled(language)
        }
    }

    private static func transcriber(for language: String) -> SpeechTranscriber {
        SpeechTranscriber(locale: Locale(identifier: language), preset: .progressiveTranscription)
    }
}

enum LanguageInstallError: Error {
    case notInstalled(String)
}
