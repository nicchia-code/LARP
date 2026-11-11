import Foundation
import SwiftData
import os

/// What happened to a call that matters to its file in the Markdown folder. `CallLifecycle` emits
/// one for each event of the call that changes what the Markdown export holds.
enum CallChange: Sendable, Equatable {
    /// `call.READY`.
    case becameReady(UUID)
    /// An event that changes what the export of the call holds: `call-summary.SUMMARY_WRITTEN`,
    /// `user.RENAME_PARTICIPANT`, `user.EDIT_LINE`, `user.TOGGLE_ACTION_ITEM`, `user.ADD_NOTE`,
    /// `user.EDIT_NOTE`, `user.DELETE_NOTE`, `user.ADD_BOOKMARK` and `user.DELETE_BOOKMARK`
    /// (`user.RESTORE_TRANSCRIPT` ends in Ready, so it is a `becameReady`).
    case exportChanged(UUID)
    /// `user.RENAME_CALL`.
    case renamed(UUID)
    /// `call.DELETED`. The call is gone, so the name of its file comes with the news.
    case deleted(UUID, markdownFileName: String?)
}

/// The files of the Markdown folder. The implementation works off the main actor; the calls come
/// one at a time.
protocol MarkdownFileWriting: Sendable {
    /// Writes `text` as UTF-8 in the file `fileName` of `folder`, atomically, replacing the file.
    /// Throws when the folder is not there or the file cannot be written.
    func write(_ text: String, named fileName: String, in folder: URL) async throws
    /// Removes the file `fileName` of `folder`; a file that is not there is not an error.
    func remove(named fileName: String, in folder: URL) async throws
    /// Whether the folder has a file, of any kind, with the name `fileName`.
    func exists(named fileName: String, in folder: URL) async -> Bool
}

/// The Markdown files on disk. An actor: its operations run one at a time and never on the main
/// actor.
actor MarkdownFolderFiles: MarkdownFileWriting {
    func write(_ text: String, named fileName: String, in folder: URL) throws {
        try Data(text.utf8).write(to: folder.appending(path: fileName, directoryHint: .notDirectory), options: .atomic)
    }

    func remove(named fileName: String, in folder: URL) throws {
        do {
            try FileManager.default.removeItem(at: folder.appending(path: fileName, directoryHint: .notDirectory))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    func exists(named fileName: String, in folder: URL) -> Bool {
        // `attributesOfItem` does not follow links, so a dangling link counts as a file too.
        (try? FileManager.default.attributesOfItem(atPath: folder.appending(path: fileName, directoryHint: .notDirectory).path)) != nil
    }
}

/// The names LARP wrote in each Markdown folder, kept in the user defaults
/// (`settings.markdownWrittenFiles`, one list of names for each folder path): a file with one of
/// these names is LARP's and may be replaced; any other file of the folder is the user's and is
/// never touched. Names compare without regard to case, as the file system does.
@MainActor
struct MarkdownWrittenNames {
    let defaults: UserDefaults

    func names(in folder: URL) -> [String] {
        all[folder.path] ?? []
    }

    func remember(_ name: String, in folder: URL) {
        var names = names(in: folder)
        guard !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        names.append(name)
        save(names, in: folder)
    }

    func forget(_ name: String, in folder: URL) {
        let names = names(in: folder)
        let kept = names.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        if kept.count != names.count { save(kept, in: folder) }
    }

    private var all: [String: [String]] {
        defaults.dictionary(forKey: SettingsKey.markdownWrittenFiles) as? [String: [String]] ?? [:]
    }

    private func save(_ names: [String], in folder: URL) {
        var all = all
        all[folder.path] = names.isEmpty ? nil : names
        defaults.set(all, forKey: SettingsKey.markdownWrittenFiles)
    }
}

/// The effects of the `markdown-folder` machine (Model `settings/markdown-folder`) on the calls:
/// keeps every ready call as a Markdown file in the folder, with the content of the Markdown
/// export, and makes the file follow the call: written when the call becomes ready, again when
/// what the export holds changes, renamed with the call and removed with it. What the user chose,
/// and whether the folder is on, is `MarkdownFolderController`'s business: this class asks it for
/// the folder (`nil` while Off) and tells it how each write went.
///
/// Jobs run one at a time, in the order they came, so two calls never choose the same file name
/// together. A file that could not be written is tried again at the next change of its call.
@MainActor
final class MarkdownFolderSync {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "markdown-folder")

    private enum Job: Sendable {
        case change(CallChange)
        case writeAll
        case barrier(CheckedContinuation<Void, Never>)
    }

    private let context: ModelContext
    /// The folder the files are written in, `nil` while the folder is Off.
    private let folder: @MainActor () -> URL?
    private let files: any MarkdownFileWriting
    /// Tells the settings whether a write succeeded.
    private let report: @MainActor (_ succeeded: Bool) -> Void
    /// The language of the interface, read when a file is written.
    private let language: @MainActor () -> AppLanguage
    private let jobs: AsyncStream<Job>.Continuation
    private var tasks: [Task<Void, Never>] = []
    /// The names LARP wrote in each folder: the only files of a folder it may replace.
    private let writtenNames: MarkdownWrittenNames

    init(
        context: ModelContext,
        folder: @escaping @MainActor () -> URL?,
        files: any MarkdownFileWriting = MarkdownFolderFiles(),
        report: @escaping @MainActor (_ succeeded: Bool) -> Void,
        language: @escaping @MainActor () -> AppLanguage = { .current },
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.folder = folder
        self.files = files
        self.report = report
        self.language = language
        writtenNames = MarkdownWrittenNames(defaults: defaults)
        let (stream, continuation) = AsyncStream<Job>.makeStream(bufferingPolicy: .unbounded)
        jobs = continuation
        tasks.append(
            Task { [weak self] in
                for await job in stream {
                    guard let self else { return }
                    await self.run(job)
                }
            })
    }

    isolated deinit {
        jobs.finish()
        for task in tasks { task.cancel() }
    }

    /// Follows the news of the calls and the folders the user chooses. Call once, at launch.
    func start(changes: AsyncStream<CallChange>, folderChosen: AsyncStream<String>) {
        guard tasks.count == 1 else { return }
        tasks.append(
            Task { [weak self] in
                for await change in changes { self?.handle(change) }
            })
        tasks.append(
            Task { [weak self] in
                for await _ in folderChosen { self?.writeAllReadyCalls() }
            })
    }

    // MARK: Events

    /// A call changed in a way its file follows. While the folder is Off nothing is done; a call
    /// that is not ready is written when it becomes ready.
    func handle(_ change: CallChange) {
        jobs.yield(.change(change))
    }

    /// `user.TURN_ON_MARKDOWN_FOLDER` and `user.CHOOSE_MARKDOWN_FOLDER`: every ready call is
    /// written into the folder at once, with names chosen anew: the files of an earlier folder
    /// stay where they are and are no longer followed.
    func writeAllReadyCalls() {
        jobs.yield(.writeAll)
    }

    /// Resolves when every job asked so far has ended.
    func waitUntilIdle() async {
        await withCheckedContinuation { continuation in
            jobs.yield(.barrier(continuation))
        }
    }

    // MARK: Jobs

    private func run(_ job: Job) async {
        switch job {
        case .barrier(let continuation):
            continuation.resume()
        case .writeAll:
            await writeAll()
        case .change(let change):
            guard let folder = folder() else { return }
            switch change {
            case .deleted(_, let fileName):
                guard let fileName else { return }
                await remove(fileName, in: folder)
            case .becameReady(let id), .exportChanged(let id), .renamed(let id):
                guard let call = call(id: id), call.state == .ready else { return }
                report(await write(call, in: folder))
            }
        }
    }

    private func writeAll() async {
        guard let folder = folder() else { return }
        let calls = ((try? context.fetch(FetchDescriptor<Call>(sortBy: [SortDescriptor(\.startedAt)]))) ?? [])
        for call in calls { call.markdownFileName = nil }
        save()
        var attempted = false
        var succeeded = true
        for id in calls.filter({ $0.state == .ready }).map(\.id) {
            guard let call = call(id: id) else { continue }
            attempted = true
            if await !write(call, in: folder) { succeeded = false }
        }
        if attempted { report(succeeded) }
    }

    /// Writes the file of `call`: the name is kept when it still fits the title, otherwise the
    /// file takes the new name and the one with the old name is removed. `false` when the file
    /// could not be written.
    private func write(_ call: Call, in folder: URL) async -> Bool {
        let id = call.id
        let language = language()
        let text = TranscriptExport.markdown(for: call, language: language)
        let previousName = call.markdownFileName
        let name = await fileName(for: call, language: language, in: folder)
        do {
            try await files.write(text, named: name, in: folder)
        } catch {
            Self.logger.error("Writing the Markdown file failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard let call = self.call(id: id) else {
            // The call was deleted while its file was written: the file goes too.
            await remove(name, in: folder)
            return true
        }
        call.markdownFileName = name
        writtenNames.remember(name, in: folder)
        save()
        if let previousName, previousName.caseInsensitiveCompare(name) != .orderedSame,
            writtenNames.names(in: folder).contains(where: { $0.caseInsensitiveCompare(previousName) == .orderedSame })
        {
            // Only a file LARP wrote is removed: a foreign file that took the old name stays.
            await remove(previousName, in: folder)
        }
        return true
    }

    private func remove(_ fileName: String, in folder: URL) async {
        do {
            try await files.remove(named: fileName, in: folder)
            writtenNames.forget(fileName, in: folder)
        } catch {
            Self.logger.error("Removing the Markdown file failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Names

    /// The name of the file of `call`: the default export file name with `.md`, with ` (2)`, ` (3)`
    /// and so on before it when another call of the folder already uses the name, or when the file
    /// is there and LARP did not write it. The name the call used is kept while it still fits the
    /// title.
    private func fileName(for call: Call, language: AppLanguage, in folder: URL) async -> String {
        let base = TranscriptExport.defaultFileName(for: call, language: language)
        let id = call.id
        let others = (try? context.fetch(FetchDescriptor<Call>())) ?? []
        let used = Set(others.filter { $0.id != id }.compactMap { $0.markdownFileName?.lowercased() })
        let written = Set(writtenNames.names(in: folder).map { $0.lowercased() })
        if let stored = call.markdownFileName, Self.isName(stored, from: base),
            await isFree(stored, in: folder, used: used, written: written)
        {
            return stored
        }
        var candidate = "\(base).md"
        var number = 2
        while !(await isFree(candidate, in: folder, used: used, written: written)) {
            candidate = "\(base) (\(number)).md"
            number += 1
        }
        return candidate
    }

    /// Whether `name` can be taken: no other call of the folder uses it, and either LARP wrote it
    /// there or no file has it.
    private func isFree(_ name: String, in folder: URL, used: Set<String>, written: Set<String>) async -> Bool {
        let key = name.lowercased()
        if used.contains(key) { return false }
        if written.contains(key) { return true }
        return !(await files.exists(named: name, in: folder))
    }

    /// Whether `name` is `base.md` or `base (<n>).md` with `n` from 2 on.
    static func isName(_ name: String, from base: String) -> Bool {
        if name == "\(base).md" { return true }
        guard name.hasPrefix("\(base) ("), name.hasSuffix(").md") else { return false }
        let number = name.dropFirst(base.count + 2).dropLast(4)
        return Int(number).map { $0 >= 2 } ?? false
    }

    // MARK: Store

    private func call(id: UUID) -> Call? {
        try? context.fetch(FetchDescriptor<Call>(predicate: #Predicate { $0.id == id })).first
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Saving the archive failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
