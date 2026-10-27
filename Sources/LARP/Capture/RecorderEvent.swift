/// What the recorder tells the rest of the app: a recording was started or ended.
/// The capture and saving of the audio react to these events.
enum RecorderEvent: Equatable, Sendable {
    /// A recording started (`RECORDING_STARTED`). `callAppName` is the name of the
    /// call app the recording is tied to, `nil` for a recording started by hand.
    case started(callAppName: String?)
    /// The recording ended (`RECORDING_STOPPED`).
    case stopped
}
