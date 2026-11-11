/// What the recorder tells the rest of the app: a recording was started, paused, resumed or
/// ended. The capture and saving of the audio react to these events.
enum RecorderEvent: Equatable, Sendable {
    /// A recording started (`RECORDING_STARTED`). `callAppName` is the name of the call app the
    /// recording is tied to, `nil` for a recording started by hand.
    case started(callAppName: String?)
    /// The recording was paused (`user.PAUSE_RECORDING`): the tracks and the live transcription
    /// take silence from now on.
    case paused
    /// The recording was resumed (`user.RESUME_RECORDING`).
    case resumed
    /// The recording ended (`RECORDING_STOPPED`).
    case stopped
}
