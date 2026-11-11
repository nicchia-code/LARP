import AppKit
import Foundation
import os

/// Tells the user that an audio file could not be imported. Replaced in tests.
@MainActor
protocol ImportFailureAlertPresenting: AnyObject {
    /// `reason` says why, in the language of the interface, in a sentence the user can read.
    func present(reason: String)
}

/// The alert "Impossibile importare il file": no call was made.
@MainActor
final class ImportFailureAlertPresenter: ImportFailureAlertPresenting {
    func present(reason: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("Impossibile importare il file")
        alert.informativeText = reason
        alert.addButton(withTitle: L10n.string("OK"))
        NSApp.activate()
        alert.runModal()
    }
}

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "import") }

    /// `user.IMPORT_AUDIO`: the file is converted, off the main actor, into the system audio track of a
    /// new call; the call is born only once that has succeeded, titled with the name of the file without
    /// its extension, started when the file was last modified, as long as its audio, with no call app
    /// and in the language chosen now, and goes to **Transcribing** or **Awaiting language**. When the
    /// file cannot be read or converted the user is told why and no call is made. Returns the call, or
    /// `nil` on failure.
    @discardableResult
    func importAudio(from source: URL) async -> Call? {
        let language = chosenLanguage()
        let id = UUID()
        let folder = AppPaths.recordingsFolder(callID: id)
        let imported: ImportedAudio
        do {
            imported = try await AudioFileImporter.convert(source, to: AudioTrack.system.fileURL(in: folder))
        } catch {
            try? FileManager.default.removeItem(at: folder)
            Self.logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            if !(error is CancellationError) {
                importFailureAlerts.present(reason: error.localizedDescription)
            }
            return nil
        }

        let languageReady = await languages.isReady(language)
        let state = CallStateMachine.stateAfterImport(languageReady: languageReady)
        let call = Call(
            id: id,
            title: Call.normalizedName(source.deletingPathExtension().lastPathComponent),
            startedAt: imported.modifiedAt,
            endedAt: imported.modifiedAt.addingTimeInterval(imported.duration),
            duration: imported.duration,
            callAppName: nil,
            transcriptionLanguage: language,
            state: state)
        call.isImported = true
        context.insert(call)
        save()
        enter(state, call: call)
        return call
    }
}
