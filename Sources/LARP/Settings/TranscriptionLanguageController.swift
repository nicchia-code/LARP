import Foundation
import Observation

/// The `transcription-language` machine: the single language in which all
/// calls are transcribed, and whether its speech model is installed.
///
/// The chosen language lives in `UserDefaults`. A new choice applies to
/// recordings that start afterwards.
@MainActor
@Observable
final class TranscriptionLanguageController: LanguageAvailability {
    /// States of the `transcription-language` machine.
    enum Status: Sendable, Equatable {
        case checking
        case downloading
        case missing
        case ready
    }

    /// The controller shared by the app: the settings window and the call
    /// lifecycle read the same instance.
    static let shared = TranscriptionLanguageController()

    /// The chosen transcription language.
    private(set) var language: TranscriptionLanguage
    private(set) var status: Status = .checking

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let models: any SpeechModels
    @ObservationIgnored private let network: any NetworkAvailabilityEvents
    @ObservationIgnored private let readyEvents = EventBroadcaster<String>()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var networkTask: Task<Void, Never>?
    /// Identifies the latest check/download; results of older ones are ignored.
    @ObservationIgnored private var generation = 0

    init(
        defaults: UserDefaults = .standard,
        models: any SpeechModels = AppleSpeechModels(),
        network: any NetworkAvailabilityEvents = NetworkMonitor.shared
    ) {
        self.defaults = defaults
        self.models = models
        self.network = network
        language =
            defaults.string(forKey: SettingsKey.transcriptionLanguage)
            .flatMap(TranscriptionLanguage.init(rawValue:)) ?? .default
    }

    // MARK: LanguageAvailability

    nonisolated func isReady(_ language: String) async -> Bool {
        await models.isInstalled(language)
    }

    nonisolated var languageReady: AsyncStream<String> {
        readyEvents.stream()
    }

    // MARK: Events

    /// App launched (Checking): installed → Ready; otherwise → Downloading.
    /// Also starts listening for the network coming back. Call once.
    func start() {
        guard networkTask == nil else { return }
        let events = network.availableEvents
        networkTask = Task { [weak self] in
            for await _ in events {
                self?.networkAvailable()
            }
        }
        evaluate()
    }

    /// `user.CHOOSE_LANGUAGE`: installed → Ready; otherwise → Downloading.
    func choose(_ newLanguage: TranscriptionLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        defaults.set(newLanguage.rawValue, forKey: SettingsKey.transcriptionLanguage)
        evaluate()
    }

    /// `macos.NETWORK_AVAILABLE`: Missing → Downloading, the download is tried
    /// again.
    func networkAvailable() {
        guard status == .missing else { return }
        evaluate()
    }

    /// Returns when the check or download in progress has finished.
    func waitUntilIdle() async {
        await task?.value
    }

    // MARK: Machine

    private func evaluate() {
        task?.cancel()
        generation += 1
        let current = generation
        let code = language.rawValue
        status = .checking
        task = Task { [weak self] in
            await self?.run(code, generation: current)
        }
    }

    private func run(_ code: String, generation current: Int) async {
        if await models.isInstalled(code) {
            becomeReady(code, generation: current)
            return
        }
        guard current == generation else { return }
        status = .downloading
        do {
            try await models.install(code)
            becomeReady(code, generation: current)
        } catch {
            guard current == generation else { return }
            status = .missing
        }
    }

    private func becomeReady(_ code: String, generation current: Int) {
        guard current == generation else { return }
        status = .ready
        readyEvents.emit(code)
    }
}
