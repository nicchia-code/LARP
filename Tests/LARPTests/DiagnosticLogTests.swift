import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Diagnostic log", .serialized)
struct DiagnosticLogTests {
    private final class Clock: Sendable {
        private let current: Mutex<Date>
        init(_ date: Date) { current = Mutex(date) }
        var now: Date { current.withLock { $0 } }
        func set(_ date: Date) { current.withLock { $0 = date } }
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, millisecond: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        parts.second = 5
        parts.nanosecond = millisecond * 1_000_000
        return Calendar(identifier: .gregorian).date(from: parts)!
    }

    private func makeFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "larp-log-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test("a line is the local time in ISO 8601 with milliseconds, the area and the message")
    func lineFormat() throws {
        let line = DiagnosticLog.line(
            date: Self.date(2026, 11, 12, 9, 3, millisecond: 42), area: .capture, message: "Microphone started")
        let parts = line.dropLast().split(separator: " ", maxSplits: 2).map(String.init)
        #expect(line.hasSuffix("\n"))
        #expect(parts.count == 3)
        #expect(parts[1] == "capture")
        #expect(parts[2] == "Microphone started")
        #expect(
            parts[0].wholeMatch(of: /2026-11-12T09:03:05\.04[12]([+-]\d{2}:\d{2}|Z)/) != nil, "timestamp \(parts[0])")
    }

    @Test("a message with line breaks stays on one line")
    func oneLinePerEvent() {
        let line = DiagnosticLog.line(date: Date(), area: .teams, message: "a\nb\r\nc")
        #expect(line.filter { $0 == "\n" }.count == 1)
    }

    @Test("lines reach the file of their day, in order, and a new day starts a new file")
    func filesPerDay() throws {
        let folder = makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let clock = Clock(Self.date(2026, 11, 12))
        let log = DiagnosticLog(folder: folder, now: { clock.now })

        log.write(area: .detection, "first")
        log.write(area: .capture, "second")
        clock.set(Self.date(2026, 11, 13, 0, 1))
        log.write(area: .teams, "third")
        log.flush()

        let first = try String(contentsOf: folder.appending(path: "LARP-2026-11-12.log"), encoding: .utf8)
        let second = try String(contentsOf: folder.appending(path: "LARP-2026-11-13.log"), encoding: .utf8)
        let firstLines = first.split(separator: "\n")
        #expect(firstLines.count == 2)
        #expect(firstLines[0].hasSuffix(" detection first"))
        #expect(firstLines[1].hasSuffix(" capture second"))
        #expect(second.split(separator: "\n").count == 1)
        #expect(second.hasSuffix(" teams third\n"))
    }

    @Test("a second log on the same folder adds to the file of the day")
    func appends() throws {
        let folder = makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Self.date(2026, 11, 12)
        let before = DiagnosticLog(folder: folder, now: { now })
        before.write(area: .capture, "one")
        before.flush()
        let again = DiagnosticLog(folder: folder, now: { now })
        again.write(area: .capture, "two")
        again.flush()
        let text = try String(contentsOf: folder.appending(path: "LARP-2026-11-12.log"), encoding: .utf8)
        #expect(text.split(separator: "\n").count == 2)
    }

    @Test("files older than 30 days are deleted, newer ones and other files stay")
    func removesOldFiles() throws {
        let folder = makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["LARP-2026-10-01.log", "LARP-2026-10-12.log", "LARP-2026-10-13.log", "LARP-2026-11-12.log", "notes.txt"] {
            try Data("x\n".utf8).write(to: folder.appending(path: name))
        }
        let log = DiagnosticLog(folder: folder, now: { Self.date(2026, 11, 12) })
        log.removeOldFilesNow()

        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(left == ["LARP-2026-10-13.log", "LARP-2026-11-12.log", "notes.txt"])
    }

    @Test("the folder is created when missing, and a failure to write is ignored")
    func failuresAreIgnored() throws {
        let folder = makeFolder().appending(path: "deeper", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let log = DiagnosticLog(folder: folder, now: { Self.date(2026, 11, 12) })
        log.write(area: .capture, "created")
        log.flush()
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "LARP-2026-11-12.log").path))

        // A file where the folder should be: nothing can be written, and nothing is thrown.
        let blocked = makeFolder()
        defer { try? FileManager.default.removeItem(at: blocked) }
        try Data().write(to: blocked)
        let failing = DiagnosticLog(folder: blocked, now: { Self.date(2026, 11, 12) })
        failing.write(area: .capture, "lost")
        failing.flush()
    }

    @Test("the log of the app lives in ~/Library/Logs/LARP")
    func appFolder() {
        #expect(AppPaths.diagnosticLogFolder.path.hasSuffix("/Library/Logs/LARP"))
    }
}
