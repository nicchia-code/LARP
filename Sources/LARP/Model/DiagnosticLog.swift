import Foundation
import Synchronization

/// The areas of the diagnostic log of LARP.
enum DiagnosticLogArea: String, Sendable, CaseIterable {
    /// The detection of call apps.
    case detection
    /// The reading of Microsoft Teams.
    case teams
    /// The capture of the microphone and of the system audio.
    case capture
}

/// The diagnostic log of LARP: always on, with no setting, in `~/Library/Logs/LARP/`, one UTF-8
/// text file per day, `LARP-<yyyy-MM-dd>.log`. It lives next to the log of macOS (`os.Logger`),
/// which it does not replace.
///
/// Each line is one event: the local date and time in ISO 8601 with milliseconds, the area and the
/// message, separated by spaces. Every line reaches the disk (`fsync`) before the next one is
/// written, so a crash or a frozen Mac loses none of the lines already written. Lines are written
/// from a private serial queue; a failure to write is ignored and never affects a recording.
///
/// It never holds audio, transcript text, names of people, titles or any other text read from
/// Teams or the calendar: only identifiers of processes and apps, durations, counts, formats and
/// reasons. Never call it from an audio thread: `write` takes a lock and allocates.
final class DiagnosticLog: @unchecked Sendable {
    /// The log of the app.
    static let shared = DiagnosticLog(folder: AppPaths.diagnosticLogFolder)

    /// Files older than this many days are deleted.
    static let retentionDays = 30
    /// How often the old files are deleted while the app runs.
    static let cleanupInterval: TimeInterval = 24 * 60 * 60

    /// Writes one line of `area` to the log of the app, `message` on one line.
    static func write(area: DiagnosticLogArea, _ message: String) {
        shared.write(area: area, message)
    }

    /// Deletes the files older than 30 days, now and then once a day while the app runs. Called
    /// once, at launch.
    static func startCleaning() {
        shared.startCleaning()
    }

    private let folder: URL
    private let queue = DispatchQueue(label: "com.larp.LARP.diagnostic-log", qos: .utility)
    private let now: @Sendable () -> Date

    // Everything below is confined to `queue`.
    private var handle: FileHandle?
    private var handleDay: String?
    private var timer: DispatchSourceTimer?

    /// - Parameters:
    ///   - folder: where the files go; created when missing.
    ///   - now: the clock; replaced in tests.
    init(folder: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.folder = folder
        self.now = now
    }

    deinit {
        timer?.cancel()
        try? handle?.close()
    }

    func write(area: DiagnosticLogArea, _ message: String) {
        let date = now()
        queue.async { [self] in
            append(Self.line(date: date, area: area, message: message), day: Self.dayString(date))
        }
    }

    /// Returns when every line written so far is on disk.
    func flush() {
        queue.sync {}
    }

    /// Deletes the files older than 30 days, and returns when it is done.
    func removeOldFilesNow() {
        queue.sync { removeOldFiles() }
    }

    func startCleaning() {
        queue.async { [self] in
            guard timer == nil else { return }
            removeOldFiles()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + Self.cleanupInterval, repeating: Self.cleanupInterval)
            timer.setEventHandler { [weak self] in self?.removeOldFiles() }
            timer.resume()
            self.timer = timer
        }
    }

    // MARK: - Format

    static func fileName(day: String) -> String { "LARP-\(day).log" }

    /// `yyyy-MM-dd` in the local time zone.
    static func dayString(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `2026-11-12T10:15:30.123+01:00 capture message`
    static func line(date: Date, area: DiagnosticLogArea, message: String) -> String {
        let oneLine = message.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        return "\(timestamp(date)) \(area.rawValue) \(oneLine)\n"
    }

    /// ISO 8601 with milliseconds, in the local time zone.
    static func timestamp(_ date: Date) -> String {
        let zone = TimeZone.current
        let parts = Calendar(identifier: .gregorian).dateComponents(in: zone, from: date)
        let milliseconds = (parts.nanosecond ?? 0) / 1_000_000
        let offset = zone.secondsFromGMT(for: date)
        let sign = offset < 0 ? "-" : "+"
        let minutes = abs(offset) / 60
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d.%03d%@%02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, min(milliseconds, 999), sign, minutes / 60, minutes % 60)
    }

    // MARK: - On the queue

    private func append(_ line: String, day: String) {
        do {
            if handleDay != day || handle == nil {
                try? handle?.close()
                handle = nil
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appending(path: Self.fileName(day: day))
                if !FileManager.default.fileExists(atPath: url.path) {
                    guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return }
                }
                let opened = try FileHandle(forWritingTo: url)
                try opened.seekToEnd()
                handle = opened
                handleDay = day
            }
            guard let handle else { return }
            try handle.write(contentsOf: Data(line.utf8))
            // On disk before the next line is written.
            try handle.synchronize()
        } catch {
            // A failure to write is ignored; the next line tries again from scratch.
            try? handle?.close()
            handle = nil
        }
    }

    private func removeOldFiles() {
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil)
        else { return }
        let cutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day, value: -Self.retentionDays, to: now()) ?? now()
        let oldest = Self.fileName(day: Self.dayString(cutoff))
        for file in files {
            let name = file.lastPathComponent
            // `LARP-<yyyy-MM-dd>.log`: the names sort as the days do.
            guard Self.isLogFileName(name), name < oldest else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func isLogFileName(_ name: String) -> Bool {
        name.wholeMatch(of: /LARP-\d{4}-\d{2}-\d{2}\.log/) != nil
    }
}
