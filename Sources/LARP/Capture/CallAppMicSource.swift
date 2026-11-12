/// A known call app started or stopped using the microphone.
enum CallAppMicEvent: Equatable, Sendable {
    case started(CallApp)
    case stopped(CallApp)
    /// A process of the app with this bundle identifier, as `KnownCallApps` lists it (for Teams,
    /// `com.microsoft.teams2` or `com.microsoft.teams`), started using the microphone. Several
    /// bundles can belong to one `CallApp`; this tells which one it was. The recorder does not
    /// react to it.
    case bundleStarted(String)
    /// No process of that bundle uses the microphone any more.
    case bundleStopped(String)
}

/// Source of microphone usage events of the known call apps. Replaced in tests.
protocol CallAppMicSource: Sendable {
    /// Events from now on. Call apps already using the microphone when the stream
    /// is created are reported as `.started` first. Ending the iteration stops the
    /// observation.
    func events() -> AsyncStream<CallAppMicEvent>
}
