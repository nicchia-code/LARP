import AppKit
import Foundation
import Observation

/// Opens the system panel that asks the user for a folder.
@MainActor
protocol MarkdownFolderPicking {
    /// The path of the folder the user chose, `nil` when the panel was cancelled. `path` is the
    /// folder the panel starts in, when there is one.
    func chooseFolder(startingAt path: String?) async -> String?
}

/// The system open panel, for folders only.
@MainActor
struct SystemMarkdownFolderPicker: MarkdownFolderPicking {
    func chooseFolder(startingAt path: String?) async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.string("Scegli la cartella per i file Markdown")
        panel.prompt = L10n.string("Scegli")
        if let path {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        // LARP has no Dock icon: the panel must be brought to the front by hand.
        NSApp.activate()
        guard await panel.begin() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}

/// The `markdown-folder` machine: whether every ready call is kept as a Markdown file in a folder
/// the user chose.
///
/// The path of the folder lives in `UserDefaults` (`settings.markdownFolder`, kept as is: the app
/// is not sandboxed); its absence means **Off**, so the machine starts **On** when the folder was
/// left on. Writing the files belongs to the call layer (`MarkdownFolderSync`), which reads
/// `folderPath`, tells the result of each write through `writeSucceeded()` and `writeFailed()`, and
/// listens to `folderChosen` to write every ready call into the new folder.
@MainActor
@Observable
final class MarkdownFolderController {
    /// States of the `markdown-folder` machine.
    enum State: Sendable, Equatable {
        case off
        /// Ready calls are kept as files in this folder (its path).
        case on(folder: String)
    }

    /// The controller shared by the app: the settings page and the call layer read the same one.
    static let shared = MarkdownFolderController()

    private(set) var state: State
    /// The last write of a file failed, and none succeeded since: the settings say so under the row.
    private(set) var hasWriteError = false

    var isOn: Bool { folderPath != nil }

    /// The path of the folder the files are written in; `nil` while Off.
    var folderPath: String? {
        if case .on(let folder) = state { folder } else { nil }
    }

    /// The folder the files are written in as a URL; `nil` while Off.
    var folderURL: URL? {
        folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// A folder was chosen, by `TURN_ON_MARKDOWN_FOLDER` or `CHOOSE_MARKDOWN_FOLDER`: every ready
    /// call is written into it at once. Carries the path of the folder.
    @ObservationIgnored private let chosen = EventBroadcaster<String>()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let picker: any MarkdownFolderPicking
    /// The system panel is open: a second request waits for the first to end.
    @ObservationIgnored private var isChoosing = false

    init(
        defaults: UserDefaults = .standard,
        picker: any MarkdownFolderPicking = SystemMarkdownFolderPicker()
    ) {
        self.defaults = defaults
        self.picker = picker
        if let path = defaults.string(forKey: SettingsKey.markdownFolder), !path.isEmpty {
            state = .on(folder: path)
        } else {
            state = .off
        }
    }

    // MARK: Events

    /// `user.TURN_ON_MARKDOWN_FOLDER`: Off → On when the user chooses a folder in the system open
    /// panel (the choice is saved and every ready call is written into it at once); Off → Off when
    /// the panel is cancelled.
    func turnOn() async {
        guard state == .off, !isChoosing else { return }
        isChoosing = true
        defer { isChoosing = false }
        guard let path = await picker.chooseFolder(startingAt: nil), !path.isEmpty else { return }
        choose(path)
    }

    /// `user.CHOOSE_MARKDOWN_FOLDER`: On → On when the user chooses another folder in the system
    /// open panel (the choice is saved, the files in the previous folder stay and every ready call
    /// is written into the new one at once); nothing changes when the panel is cancelled.
    func chooseAnother() async {
        guard case .on(let current) = state, !isChoosing else { return }
        isChoosing = true
        defer { isChoosing = false }
        guard let path = await picker.chooseFolder(startingAt: current), !path.isEmpty else { return }
        choose(path)
    }

    /// `user.TURN_OFF_MARKDOWN_FOLDER`: On → Off. The choice is saved; the files written stay.
    func turnOff() {
        guard state != .off else { return }
        defaults.removeObject(forKey: SettingsKey.markdownFolder)
        state = .off
        hasWriteError = false
    }

    /// A file was written: the message under the row goes away.
    func writeSucceeded() {
        hasWriteError = false
    }

    /// A file could not be written: the settings say so until a write succeeds. The call is tried
    /// again at its next change.
    func writeFailed() {
        guard isOn else { return }
        hasWriteError = true
    }

    /// A new stream that yields the path of the folder every time one is chosen, for the call
    /// layer.
    var folderChosen: AsyncStream<String> {
        chosen.stream()
    }

    private func choose(_ path: String) {
        defaults.set(path, forKey: SettingsKey.markdownFolder)
        state = .on(folder: path)
        hasWriteError = false
        chosen.emit(path)
    }
}
