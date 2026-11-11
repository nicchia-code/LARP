import Carbon.HIToolbox
import Foundation
import Testing

@testable import LARP

/// A registrar that remembers what is registered and refuses the combinations the test names.
@MainActor
private final class FakeHotKeys: HotKeyRegistering {
    var onPressed: (@MainActor (Shortcut) -> Void)?
    private(set) var registered: [Shortcut: KeyCombination] = [:]
    var refused: Set<KeyCombination> = []

    func register(_ combination: KeyCombination, for shortcut: Shortcut) -> Bool {
        registered[shortcut] = nil
        guard !refused.contains(combination) else { return false }
        registered[shortcut] = combination
        return true
    }

    func unregister(_ shortcut: Shortcut) {
        registered[shortcut] = nil
    }

    func press(_ shortcut: Shortcut) {
        guard registered[shortcut] != nil else { return }
        onPressed?(shortcut)
    }
}

@MainActor
private final class Performed {
    var shortcuts: [Shortcut] = []
}

@Suite("Shortcuts", .serialized)
@MainActor
struct ShortcutsTests {
    private let defaults: UserDefaults
    private let suiteName = "ShortcutsTests-\(UUID().uuidString)"
    private let hotKeys = FakeHotKeys()

    private let optionCommandK = KeyCombination(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey | cmdKey))
    private let controlShiftF5 = KeyCombination(keyCode: UInt32(kVK_F5), modifiers: UInt32(controlKey | shiftKey))

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    private func makeController() -> ShortcutsController {
        ShortcutsController(registrar: hotKeys, defaults: defaults)
    }

    // MARK: Defaults and storage

    @Test("without a saved choice the shortcuts are ⌥⌘R and ⌥⌘B, registered at start")
    func defaultCombinations() {
        let controller = makeController()
        controller.start { _ in }

        #expect(controller.display(for: .record) == "⌥⌘R")
        #expect(controller.display(for: .bookmark) == "⌥⌘B")
        #expect(hotKeys.registered[.record] == .recordDefault)
        #expect(hotKeys.registered[.bookmark] == .bookmarkDefault)
    }

    @Test("a shortcut saved as none has no combination and is not registered; the other keeps its default")
    func storedNone() {
        defaults.set("none", forKey: SettingsKey.shortcutRecord)
        let controller = makeController()
        controller.start { _ in }

        #expect(controller.combination(for: .record) == nil)
        #expect(controller.display(for: .record) == nil)
        #expect(hotKeys.registered[.record] == nil)
        #expect(hotKeys.registered[.bookmark] == .bookmarkDefault)
    }

    @Test("a saved combination is read back; an unreadable value means the default")
    func storedCombination() {
        defaults.set(optionCommandK.storedValue, forKey: SettingsKey.shortcutBookmark)
        defaults.set("garbage", forKey: SettingsKey.shortcutRecord)
        let controller = makeController()

        #expect(controller.combination(for: .bookmark) == optionCommandK)
        #expect(controller.combination(for: .record) == .recordDefault)
    }

    @Test("the keys are shown with modifiers first")
    func display() {
        #expect(optionCommandK.displayString == "⌥⌘K")
        #expect(controlShiftF5.displayString == "⌃⇧F5")
    }

    // MARK: user.CHANGE_SHORTCUT

    @Test("a free combination macOS accepts is saved, registered and replaces the previous one")
    func changeAccepted() {
        let controller = makeController()
        controller.start { _ in }

        controller.change(.record, to: optionCommandK)

        #expect(controller.combination(for: .record) == optionCommandK)
        #expect(hotKeys.registered[.record] == optionCommandK)
        #expect(controller.rejections[.record] == nil)
        #expect(defaults.string(forKey: SettingsKey.shortcutRecord) == optionCommandK.storedValue)
        #expect(makeController().combination(for: .record) == optionCommandK)
    }

    @Test("the combination of the other shortcut is refused and the previous one stays")
    func changeUsedByOther() {
        let controller = makeController()
        controller.start { _ in }

        controller.change(.record, to: .bookmarkDefault)

        #expect(controller.combination(for: .record) == .recordDefault)
        #expect(hotKeys.registered[.record] == .recordDefault)
        #expect(controller.rejections[.record]?.message == "Già usata da un'altra scorciatoia")
        #expect(defaults.string(forKey: SettingsKey.shortcutRecord) == nil)
    }

    @Test("a combination macOS refuses is refused and the previous one stays registered")
    func changeRefusedBySystem() {
        let controller = makeController()
        controller.start { _ in }
        hotKeys.refused = [optionCommandK]

        controller.change(.bookmark, to: optionCommandK)

        #expect(controller.combination(for: .bookmark) == .bookmarkDefault)
        #expect(hotKeys.registered[.bookmark] == .bookmarkDefault)
        #expect(controller.rejections[.bookmark]?.message == "Combinazione non disponibile")
        #expect(defaults.string(forKey: SettingsKey.shortcutBookmark) == nil)
    }

    @Test("a later accepted change takes the reason away")
    func rejectionGoesAway() {
        let controller = makeController()
        controller.start { _ in }
        controller.change(.record, to: .bookmarkDefault)

        controller.change(.record, to: controlShiftF5)

        #expect(controller.rejections[.record] == nil)
        #expect(controller.combination(for: .record) == controlShiftF5)
    }

    @Test("after the other shortcut leaves a combination, this one can take it")
    func takingFreedCombination() {
        let controller = makeController()
        controller.start { _ in }
        controller.clear(.bookmark)

        controller.change(.record, to: .bookmarkDefault)

        #expect(controller.combination(for: .record) == .bookmarkDefault)
    }

    // MARK: user.CLEAR_SHORTCUT

    @Test("clearing a shortcut unregisters it and saves the choice")
    func clear() {
        let controller = makeController()
        controller.start { _ in }

        controller.clear(.record)

        #expect(controller.combination(for: .record) == nil)
        #expect(hotKeys.registered[.record] == nil)
        #expect(hotKeys.registered[.bookmark] == .bookmarkDefault)
        #expect(defaults.string(forKey: SettingsKey.shortcutRecord) == "none")
        #expect(makeController().combination(for: .record) == nil)
    }

    // MARK: Pressing and recording a new combination

    @Test("pressing a registered combination runs its shortcut")
    func pressing() {
        let controller = makeController()
        let performed = Performed()
        controller.start { performed.shortcuts.append($0) }

        hotKeys.press(.bookmark)
        hotKeys.press(.record)
        controller.clear(.record)
        hotKeys.press(.record)

        #expect(performed.shortcuts == [.bookmark, .record])
    }

    @Test("while a combination is being recorded the shortcuts are off, and come back afterwards")
    func suspendAndResume() {
        let controller = makeController()
        controller.start { _ in }

        controller.suspend()
        #expect(hotKeys.registered.isEmpty)

        controller.resume()
        #expect(hotKeys.registered[.record] == .recordDefault)
        #expect(hotKeys.registered[.bookmark] == .bookmarkDefault)
    }

    @Test("a saved combination macOS refuses at start is shown as unavailable, and a refusal stays shown after recording")
    func savedCombinationRefusedAtStart() {
        hotKeys.refused = [.bookmarkDefault]
        let controller = makeController()
        controller.start { _ in }

        #expect(controller.rejections[.bookmark] == .unavailable)
        #expect(controller.rejections[.record] == nil)

        controller.suspend()
        controller.change(.record, to: .bookmarkDefault)
        controller.resume()
        #expect(controller.rejections[.record] == .usedByOther)
    }
}
