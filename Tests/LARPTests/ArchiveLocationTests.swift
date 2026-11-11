import Foundation
import Testing

@testable import LARP

@MainActor
private final class FakeRevealer: ArchiveRevealing {
    private(set) var revealed: [URL] = []

    func reveal(_ folder: URL) {
        revealed.append(folder)
    }
}

@Suite("Archive location")
@MainActor
struct ArchiveLocationTests {
    @Test("the archive is the folder LARP of Application Support")
    func defaultFolder() {
        #expect(ArchiveLocationController.shared.folder == AppPaths.applicationSupportFolder)
        #expect(ArchiveLocationController.shared.folder.lastPathComponent == "LARP")
    }

    @Test("user.REVEAL_ARCHIVE asks the Finder to select the folder of the archive")
    func reveal() {
        let revealer = FakeRevealer()
        let folder = URL(fileURLWithPath: "/Users/anna/Library/Application Support/LARP", isDirectory: true)
        let controller = ArchiveLocationController(folder: folder, revealer: revealer)

        controller.reveal()

        #expect(revealer.revealed == [folder])
    }

    @Test("the path is shortened with ~ inside the home folder and left alone elsewhere")
    func displayPath() {
        let inHome = ArchiveLocationController(
            folder: URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/LARP", isDirectory: true),
            revealer: FakeRevealer())
        #expect(inHome.displayPath == "~/Library/Application Support/LARP")

        let elsewhere = ArchiveLocationController(
            folder: URL(fileURLWithPath: "/Volumes/Disco/LARP", isDirectory: true), revealer: FakeRevealer())
        #expect(elsewhere.displayPath == "/Volumes/Disco/LARP")
    }
}
