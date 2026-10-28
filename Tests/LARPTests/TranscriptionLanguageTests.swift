import Foundation
import ServiceManagement
import Synchronization
import Testing

@testable import LARP

/// A `SpeechModels` whose installed languages and installation are controlled
/// by the test.
private final class FakeSpeechModels: SpeechModels {
    private let installed: Mutex<Set<String>>
    private let installBehavior: Mutex<@Sendable (String) async throws -> Void>
    private let installs = Mutex<[String]>([])
    private let completed = Mutex(0)

    init(installed: Set<String> = [], install: @escaping @Sendable (String) async throws -> Void = { _ in }) {
        self.installed = Mutex(installed)
        installBehavior = Mutex(install)
    }

    var installCalls: [String] { installs.withLock { $0 } }
    /// How many installations ran to their end without failing.
    var completedInstalls: Int { completed.withLock { $0 } }

    func setInstall(_ behavior: @escaping @Sendable (String) async throws -> Void) {
        installBehavior.withLock { $0 = behavior }
    }

    func isInstalled(_ language: String) async -> Bool {
        installed.withLock { $0.contains(language) }
    }

    func install(_ language: String) async throws {
        installs.withLock { $0.append(language) }
        let behavior = installBehavior.withLock { $0 }
        try await behavior(language)
        _ = installed.withLock { $0.insert(language) }
        completed.withLock { $0 += 1 }
    }
}

private struct DownloadFailure: Error {}

/// Lets a test hold an installation until it decides to finish it.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters = []
    }
}

/// A network whose events the test emits. It also counts how many times the
/// consumer asked for the next event: that happens only after it has handled
/// the previous one.
private final class FakeNetwork: NetworkAvailabilityEvents {
    private let broadcaster = EventBroadcaster<Void>()
    private let pulls = Mutex(0)

    var requestedEvents: Int { pulls.withLock { $0 } }

    var availableEvents: AsyncStream<Void> {
        let source = EventSource(broadcaster.stream().makeAsyncIterator())
        return AsyncStream(unfolding: {
            self.pulls.withLock { $0 += 1 }
            return await source.next()
        })
    }

    func returnOnline() { broadcaster.emit(()) }
}

/// Hands the events of one stream to the single consumer that pulls them.
private final class EventSource: @unchecked Sendable {
    private var iterator: AsyncStream<Void>.Iterator

    init(_ iterator: AsyncStream<Void>.Iterator) { self.iterator = iterator }

    func next() async -> Void? { await iterator.next() }
}

private final class FakeLoginItem: LoginItem {
    var status: SMAppService.Status
    var failure: Error?

    init(status: SMAppService.Status = .notRegistered) { self.status = status }

    func register() throws {
        if let failure { throw failure }
        status = .enabled
    }

    func unregister() throws {
        if let failure { throw failure }
        status = .notRegistered
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<400 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Condition not reached in time", sourceLocation: sourceLocation)
}

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

@Suite("TranscriptionLanguage", .serialized)
@MainActor
struct TranscriptionLanguageTests {
    @Test("the default language at first launch is Italian and the machine starts in Checking")
    func defaultsToItalian() {
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: FakeSpeechModels(), network: FakeNetwork())
        #expect(controller.language == .italian)
        #expect(controller.status == .checking)
    }

    @Test("launch with the model installed goes to Ready and emits LANGUAGE_READY")
    func launchInstalledGoesReady() async {
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: FakeSpeechModels(installed: ["it-IT"]), network: FakeNetwork())
        var events = controller.languageReady.makeAsyncIterator()
        controller.start()
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)
        #expect(await events.next() == "it-IT")
    }

    @Test("launch without the model goes to Downloading, then Ready when installed")
    func launchNotInstalledDownloads() async {
        let gate = Gate()
        let models = FakeSpeechModels(install: { _ in await gate.wait() })
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: FakeNetwork())
        var events = controller.languageReady.makeAsyncIterator()
        controller.start()
        await waitUntil { !models.installCalls.isEmpty }
        #expect(controller.status == .downloading)
        #expect(models.installCalls == ["it-IT"])
        await gate.open()
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)
        #expect(await events.next() == "it-IT")
    }

    @Test("a failed download goes to Missing without LANGUAGE_READY")
    func failedDownloadGoesMissing() async {
        let models = FakeSpeechModels(install: { _ in throw DownloadFailure() })
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: FakeNetwork())
        controller.start()
        await controller.waitUntilIdle()
        #expect(controller.status == .missing)
    }

    @Test("Missing retries the download when the network returns")
    func missingRetriesOnNetwork() async {
        let models = FakeSpeechModels(install: { _ in throw DownloadFailure() })
        let network = FakeNetwork()
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: network)
        var events = controller.languageReady.makeAsyncIterator()
        controller.start()
        await controller.waitUntilIdle()
        #expect(controller.status == .missing)

        models.setInstall { _ in }
        network.returnOnline()
        await waitUntil { controller.status == .ready }
        #expect(models.installCalls == ["it-IT", "it-IT"])
        #expect(await events.next() == "it-IT")
    }

    @Test("the network returning does nothing outside Missing")
    func networkIgnoredWhenReady() async {
        let models = FakeSpeechModels(installed: ["it-IT"])
        let network = FakeNetwork()
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: network)
        controller.start()
        await controller.waitUntilIdle()
        network.returnOnline()
        await waitUntil { network.requestedEvents >= 2 }
        #expect(controller.status == .ready)
        #expect(models.installCalls.isEmpty)
    }

    @Test("a new app launch retries a missing language")
    func relaunchRetriesMissing() async {
        let defaults = makeDefaults()
        let failing = FakeSpeechModels(install: { _ in throw DownloadFailure() })
        let first = TranscriptionLanguageController(defaults: defaults, models: failing, network: FakeNetwork())
        first.start()
        await first.waitUntilIdle()
        #expect(first.status == .missing)

        let second = TranscriptionLanguageController(
            defaults: defaults, models: FakeSpeechModels(), network: FakeNetwork())
        second.start()
        await second.waitUntilIdle()
        #expect(second.status == .ready)
    }

    @Test("choosing an installed language goes to Ready and is stored")
    func chooseInstalledGoesReady() async {
        let defaults = makeDefaults()
        let controller = TranscriptionLanguageController(
            defaults: defaults, models: FakeSpeechModels(installed: ["it-IT", "en-US"]), network: FakeNetwork())
        controller.start()
        await controller.waitUntilIdle()

        controller.choose(.english)
        await controller.waitUntilIdle()
        #expect(controller.language == .english)
        #expect(controller.status == .ready)
        #expect(defaults.string(forKey: SettingsKey.transcriptionLanguage) == "en-US")
    }

    @Test("choosing a language that is not installed starts its download")
    func chooseNotInstalledDownloads() async {
        let gate = Gate()
        let models = FakeSpeechModels(installed: ["it-IT"], install: { _ in await gate.wait() })
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: FakeNetwork())
        controller.start()
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)

        controller.choose(.english)
        await waitUntil { !models.installCalls.isEmpty }
        #expect(controller.status == .downloading)
        #expect(models.installCalls == ["en-US"])
        await gate.open()
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)
    }

    @Test("choosing another language from Missing leaves the failed download behind")
    func chooseFromMissing() async {
        let models = FakeSpeechModels(installed: ["en-US"], install: { _ in throw DownloadFailure() })
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: FakeNetwork())
        controller.start()
        await controller.waitUntilIdle()
        #expect(controller.status == .missing)

        controller.choose(.english)
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)
    }

    @Test("a download of a language no longer chosen does not change the state")
    func staleDownloadIsIgnored() async {
        let gate = Gate()
        let models = FakeSpeechModels(installed: ["en-US"], install: { _ in await gate.wait() })
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: models, network: FakeNetwork())
        controller.start()
        await waitUntil { !models.installCalls.isEmpty }

        controller.choose(.english)
        await controller.waitUntilIdle()
        #expect(controller.status == .ready)
        await gate.open()
        await waitUntil { models.completedInstalls == 1 }
        #expect(controller.language == .english)
        #expect(controller.status == .ready)
    }

    @Test("the stored language is used at the next launch")
    func storedLanguageIsRestored() {
        let defaults = makeDefaults()
        defaults.set("en-US", forKey: SettingsKey.transcriptionLanguage)
        let controller = TranscriptionLanguageController(
            defaults: defaults, models: FakeSpeechModels(), network: FakeNetwork())
        #expect(controller.language == .english)
    }

    @Test("isReady answers from the installed models")
    func isReadyReflectsInstalledModels() async {
        let controller = TranscriptionLanguageController(
            defaults: makeDefaults(), models: FakeSpeechModels(installed: ["en-US"]), network: FakeNetwork())
        #expect(await controller.isReady("en-US"))
        #expect(await controller.isReady("it-IT") == false)
    }

    @Test("the Italian and English choices map to it-IT and en-US")
    func languageCodes() {
        #expect(TranscriptionLanguage.allCases.map(\.rawValue) == ["it-IT", "en-US"])
        #expect(TranscriptionLanguage.allCases.map(\.displayName) == ["Italiano", "English"])
    }
}

@Suite("LaunchAtLogin")
@MainActor
struct LaunchAtLoginTests {
    @Test("the switch is off when the login item is not registered")
    func offByDefault() {
        let launch = LaunchAtLogin(item: FakeLoginItem(), defaults: makeDefaults())
        #expect(launch.isEnabled == false)
    }

    @Test("the switch reflects the real state of the login item")
    func reflectsRealState() {
        let item = FakeLoginItem(status: .enabled)
        let defaults = makeDefaults()
        let launch = LaunchAtLogin(item: item, defaults: defaults)
        #expect(launch.isEnabled)
        item.status = .notRegistered
        launch.refresh()
        #expect(launch.isEnabled == false)
        #expect(defaults.bool(forKey: SettingsKey.launchAtLogin) == false)
    }

    @Test("turning the switch on registers the login item, off unregisters it")
    func togglesLoginItem() {
        let item = FakeLoginItem()
        let launch = LaunchAtLogin(item: item, defaults: makeDefaults())
        launch.setEnabled(true)
        #expect(item.status == .enabled)
        #expect(launch.isEnabled)
        launch.setEnabled(false)
        #expect(item.status == .notRegistered)
        #expect(launch.isEnabled == false)
    }

    @Test("a registration that fails leaves the switch off with a message")
    func failedRegistration() {
        let item = FakeLoginItem()
        item.failure = DownloadFailure()
        let launch = LaunchAtLogin(item: item, defaults: makeDefaults())
        launch.setEnabled(true)
        #expect(launch.isEnabled == false)
        #expect(launch.errorMessage != nil)
    }
}
