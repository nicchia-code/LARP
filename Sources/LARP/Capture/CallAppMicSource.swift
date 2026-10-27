/// A known call app started or stopped using the microphone.
enum CallAppMicEvent: Equatable, Sendable {
    case started(CallApp)
    case stopped(CallApp)
}

/// Source of microphone usage events of the known call apps. Replaced in tests.
protocol CallAppMicSource: Sendable {
    /// Events from now on. Call apps already using the microphone when the stream
    /// is created are reported as `.started` first. Ending the iteration stops the
    /// observation.
    func events() -> AsyncStream<CallAppMicEvent>
}
