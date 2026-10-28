import SwiftData
import SwiftUI

/// Menu bar app (no Dock icon, see `LSUIElement` in Info.plist) with an archive
/// window and a settings scene.
@main
struct LARPApp: App {
    /// Identifier of the archive window, used with `openWindow(id:)`.
    static let archiveWindowID = "archive"

    private let modelContainer: ModelContainer
    private let callLifecycle: CallLifecycle

    init() {
        do {
            modelContainer = try ArchiveStore.makeContainer()
        } catch {
            fatalError("Impossibile aprire l'archivio: \(error)")
        }
        TranscriptionLanguageController.shared.start()
        TranscriptRefinementController.shared.appLaunched()
        // The call machine reacts to the recorder and to the language readiness.
        callLifecycle = CallLifecycle(
            container: modelContainer,
            languages: TranscriptionLanguageController.shared,
            chosenLanguage: { TranscriptionLanguageController.shared.language.rawValue },
            capture: CallAudioCapture(events: { event in
                Task { @MainActor in Recorder.shared.captureEvent(event) }
            }),
            transcription: SpeechTranscriptionService(),
            captureFailureAlerts: CaptureFailureAlertPresenter(),
            endRecorderRecording: { Recorder.shared.stopRecording() },
            separator: ParticipantSeparator(),
            refiner: OmpTranscriptRefiner(),
            refinementIsOn: { TranscriptRefinementController.shared.isOn }
        )
        callLifecycle.start(recorderEvents: Recorder.shared.events)
        // `macos.NETWORK_AVAILABLE`: calls waiting to separate participants or to be refined try again.
        let networkEvents = NetworkMonitor.shared.availableEvents
        let lifecycle = callLifecycle
        Task {
            for await _ in networkEvents {
                lifecycle.networkAvailable()
            }
        }
        // `user.TURN_OFF_REFINEMENT`: the refinements in progress stop.
        let turnOffEvents = TranscriptRefinementController.shared.turnOffEvents
        Task {
            for await _ in turnOffEvents {
                lifecycle.turnOffRefinement()
            }
        }
        Recorder.shared.startMonitoring()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(recorder: Recorder.shared)
        } label: {
            MenuBarLabel(recorder: Recorder.shared)
        }

        Window("Archivio", id: Self.archiveWindowID) {
            ArchiveView()
        }
        .modelContainer(modelContainer)
        .environment(callLifecycle)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
