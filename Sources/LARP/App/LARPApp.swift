import AppKit
import SwiftData
import SwiftUI

/// Menu bar app (no Dock icon, see `LSUIElement` in Info.plist). The menu bar icon with its popover
/// (`StatusItemController`) and the main window (`MainWindowController`) are drawn by AppKit, so
/// that LARP's own surfaces carry no system chrome; the app has no SwiftUI window scene.
@main
struct LARPApp: App {
    private let modelContainer: ModelContainer
    private let callLifecycle: CallLifecycle
    private let markdownFolderSync: MarkdownFolderSync

    init() {
        // The three fonts of the visual language, before any view is drawn.
        LARPFont.register()
        do {
            modelContainer = try ArchiveStore.makeContainer()
        } catch {
            fatalError("Impossibile aprire l'archivio: \(error)")
        }
        TranscriptionLanguageController.shared.start()
        AssistantStatusController.shared.appLaunched()
        // `macos.APP_LAUNCHED` for the calendar: what macOS grants is read again.
        CalendarAccessController.shared.appLaunched()
        // `macos.APP_LAUNCHED` for Teams access: the Accessibility permission is read.
        TeamsAccessController.shared.appLaunched()
        // The call machine reacts to the recorder and to the language readiness.
        let live = RecordingViewController.shared.state
        let levelRelay = LevelRelay { levels in
            for (track, level) in levels { live.levels(track, level) }
        }
        callLifecycle = CallLifecycle(
            container: modelContainer,
            languages: TranscriptionLanguageController.shared,
            chosenLanguage: { TranscriptionLanguageController.shared.language.rawValue },
            capture: CallAudioCapture(
                events: { event in
                    Task { @MainActor in Recorder.shared.captureEvent(event) }
                },
                // At most 20 times a second to the main actor, both tracks together.
                levels: { track, level in levelRelay.submit(track, level) }),
            transcription: SpeechTranscriptionService(),
            captureFailureAlerts: CaptureFailureAlertPresenter(),
            endRecorderRecording: { Recorder.shared.stopRecording() },
            separator: ParticipantSeparator(),
            refiner: OmpTranscriptRefiner(),
            refinementIsOn: { TranscriptRefinementController.shared.isOn },
            summarizer: OmpTranscriptRefiner(),
            summariesAreOn: { CallSummariesController.shared.isOn },
            summaryLanguage: { SummaryLanguageController.shared.choice },
            live: live
        )
        callLifecycle.start(recorderEvents: Recorder.shared.events)
        // `teams.*`: what Teams shows of its meeting goes to the call being recorded; Teams is read
        // while Teams access is allowed.
        let teamsMeeting = TeamsMeetingController.shared
        callLifecycle.teamsMeeting = { teamsMeeting.meeting }
        // The calendar event in progress when a recording starts (while the calendar is connected),
        // and "Identifica i parlanti": the call takes names from Teams and the calendar, and gives
        // them to its participants, only while the switch is on.
        callLifecycle.calendarMeeting = { CalendarAccessController.shared.meetingInProgress() }
        callLifecycle.speakerIdentificationIsOn = { SpeakerIdentificationController.shared.isOn }
        let teamsNews = teamsMeeting.news
        let teamsLifecycle = callLifecycle
        Task {
            for await news in teamsNews {
                teamsLifecycle.teamsMeetingNews(news)
            }
        }
        teamsMeeting.start()
        // `macos.NETWORK_AVAILABLE`: calls waiting to separate participants, to be refined or to be summarised try again.
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
        // `user.TURN_OFF_SUMMARY`: the summaries in progress stop.
        let summaryTurnOffEvents = CallSummariesController.shared.turnOffEvents
        Task {
            for await _ in summaryTurnOffEvents {
                lifecycle.turnOffSummary()
            }
        }
        // `user.CHOOSE_AUDIO_RETENTION`: the calls are checked against the days chosen, at once.
        lifecycle.audioRetentionDays = { AudioRetentionController.shared.retention.days }
        let retentionLimits = AudioRetentionController.shared.limitEvents
        Task {
            for await _ in retentionLimits {
                await lifecycle.checkAudioRetention()
            }
        }
        // `user.TURN_OFF_QUESTIONS`: the question being answered and the translation in progress end at once.
        let questionsTurnOffEvents = CallQuestionsController.shared.turnOffEvents
        Task {
            for await _ in questionsTurnOffEvents {
                MainWindowController.shared.model.questionsTurnedOff()
            }
        }
        // `user.CHOOSE_MICROPHONE`: a recording in progress moves to the microphone chosen at once.
        let microphoneChanges = MicrophoneChoiceController.shared.changes
        let capture = callLifecycle.capture
        Task {
            for await _ in microphoneChanges {
                capture.microphoneChoiceChanged()
            }
        }
        MicrophoneChoiceController.shared.start()
        // The Markdown folder: every ready call is kept as a file there, and the settings are told how
        // each write went. The settings never depend on the call layer, so it is wired here.
        let markdownFolder = MarkdownFolderController.shared
        markdownFolderSync = MarkdownFolderSync(
            context: modelContainer.mainContext,
            folder: { markdownFolder.folderURL },
            report: { succeeded in
                if succeeded { markdownFolder.writeSucceeded() } else { markdownFolder.writeFailed() }
            })
        markdownFolderSync.start(changes: callLifecycle.callChanges.stream(), folderChosen: markdownFolder.folderChosen)
        // The pill and the live window act on the recorder and on the call being recorded.
        RecordingViewController.shared.connect(recorder: Recorder.shared, lifecycle: callLifecycle)
        // The global shortcuts: start or stop the recording, add a bookmark.
        let shortcutActions = ShortcutActions(
            recorder: Recorder.shared, lifecycle: callLifecycle, playback: PlaybackController.shared)
        ShortcutsController.shared.start { shortcutActions.perform($0) }
        // Call detection: the recorder hears the news of "Rileva le call" and of the chips of the
        // call apps. The settings never depend on the call layer, so it is wired here.
        let callDetection = CallDetectionController.shared
        let detectionTurnedOn = callDetection.turnOnEvents
        let detectionTurnedOff = callDetection.turnOffEvents
        let appsWatched = callDetection.watchEvents
        let appsUnwatched = callDetection.unwatchEvents
        Task {
            for await _ in detectionTurnedOn { Recorder.shared.callDetectionTurnedOn() }
        }
        Task {
            for await _ in detectionTurnedOff { Recorder.shared.callDetectionTurnedOff() }
        }
        Task {
            for await app in appsWatched { Recorder.shared.appWatched(app) }
        }
        Task {
            for await app in appsUnwatched { Recorder.shared.appUnwatched(app) }
        }
        Recorder.shared.startMonitoring()
        // The main window and the menu bar icon with its popover.
        MainWindowController.shared.configure(container: modelContainer, lifecycle: callLifecycle)
        StatusItemController.shared.start(recorder: Recorder.shared)
        // `macos.APP_LAUNCHED` for the welcome window: it opens once the app has finished launching.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { OnboardingController.shared.appLaunched() }
        }
    }

    var body: some Scene {
        // A SwiftUI app needs a scene; this one never shows anything (LARP has no menu bar of its own).
        Settings {
            EmptyView()
        }
    }
}
