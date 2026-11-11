import Foundation

/// `UserDefaults` keys of the app settings. Use them with `@AppStorage` or
/// `UserDefaults.standard`.
enum SettingsKey {
    /// Language used to transcribe calls (locale identifier, e.g. `it-IT`).
    static let transcriptionLanguage = "settings.transcriptionLanguage"
    /// Whether transcripts are refined by omp (`Bool`, off by default).
    static let transcriptRefinement = "settings.transcriptRefinement"
    /// Whether calls are summarised by omp (`Bool`, off by default).
    static let callSummaries = "settings.callSummaries"
    /// Language of the summaries: `call` ("Come la call"), `it-IT` or `en-US`; absent or unknown
    /// means `call`.
    static let summaryLanguage = "settings.summaryLanguage"
    /// Whether questions about a call and translations of its transcript are made by omp (`Bool`,
    /// off by default).
    static let callQuestions = "settings.callQuestions"
    /// Whether the app starts at login (`Bool`).
    static let launchAtLogin = "settings.launchAtLogin"
    /// Whether the welcome window was ended (`Bool`, off by default).
    static let onboardingDone = "settings.onboardingDone"
    /// Key code and modifiers of the "start or stop recording" shortcut, or `none` when removed;
    /// absent means ⌥⌘R.
    static let shortcutRecord = "settings.shortcutRecord"
    /// Key code and modifiers of the "add a bookmark" shortcut, or `none` when removed;
    /// absent means ⌥⌘B.
    static let shortcutBookmark = "settings.shortcutBookmark"
    /// The unique identifier of the chosen input device, as Core Audio reports it; absent means
    /// "Predefinito di sistema".
    static let microphone = "settings.microphone"
    /// The name of the chosen input device, kept for when it is not connected.
    static let microphoneName = "settings.microphoneName"
    /// The path of the folder chosen for the Markdown files of the calls, kept as is (the app is not
    /// sandboxed); absent means the Markdown folder is off.
    static let markdownFolder = "settings.markdownFolder"
    /// The names of the files LARP wrote in each Markdown folder (`[String: [String]]`, the folder
    /// path to its list of names): only these files of a folder are replaced or removed. Absent
    /// means none.
    static let markdownWrittenFiles = "settings.markdownWrittenFiles"
    /// Whether the call apps that start using the microphone give a proposal or an automatic
    /// recording, "Rileva le call" (`Bool`, on by default).
    static let callDetection = "settings.callDetection"
    /// The names of the known call apps the user turned off, as in `KnownCallApps` (`[String]`);
    /// every other known call app is watched. Absent means none; a name no longer known is ignored.
    static let unwatchedCallApps = "settings.unwatchedCallApps"
    /// Whether a detected call is recorded on its own when the permissions are already granted
    /// (`Bool`, off by default).
    static let autoRecording = "settings.autoRecording"
    /// Times the audio of a call is played at: 0.75, 1, 1.25, 1.5 or 2; absent or any other value
    /// means 1.
    static let playbackSpeed = "playback.speed"
    /// Whether playback skips the silences (`Bool`, off by default).
    static let playbackSkipSilence = "playback.skipSilence"
    /// Whether the user connected the calendar of the Mac (`Bool`, off by default); what macOS
    /// grants is kept in memory only.
    static let calendarConnected = "settings.calendarConnected"
    /// Whether the Accessibility permission was seen granted at least once (`Bool`, off by
    /// default), so that its loss after a new version of the app can be told. The permission
    /// itself is kept in memory only.
    static let teamsAccessGranted = "settings.teamsAccessGranted"
    /// Whether Teams and the calendar give names to the participants of calls and offer them when a
    /// participant is renamed, "Identifica i parlanti" (`Bool`, on by default).
    static let speakerIdentification = "settings.speakerIdentification"
    /// How many days the audio of a call is kept, counted from its start: 30 or 90; absent means
    /// "Sempre", and any other value reads as "Sempre".
    static let audioRetentionDays = "settings.audioRetentionDays"
}
