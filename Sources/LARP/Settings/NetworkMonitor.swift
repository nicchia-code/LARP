import Network
import Synchronization

/// Source of the `macos.NETWORK_AVAILABLE` event: the Mac is connected to the
/// internet again. Replaceable in tests.
protocol NetworkAvailabilityEvents: Sendable {
    /// A new stream that yields every time the network becomes available
    /// again (a change from unreachable to reachable). Each access returns an
    /// independent stream, so several consumers can listen at the same time.
    var availableEvents: AsyncStream<Void> { get }
}

/// Watches the network with `NWPathMonitor` and emits an event every time the
/// path goes from unsatisfied to satisfied.
final class NetworkMonitor: NetworkAvailabilityEvents {
    /// The monitor shared by the app: the settings (language download) and the
    /// call machine (separation retry) listen to the same one.
    static let shared = NetworkMonitor()

    /// State shared with the path handler (a `Mutex` cannot be captured).
    private final class State: Sendable {
        let broadcaster = EventBroadcaster<Void>()
        let wasSatisfied = Mutex<Bool?>(nil)

        func update(satisfied: Bool) {
            let previous = wasSatisfied.withLock { state in
                let previous = state
                state = satisfied
                return previous
            }
            if satisfied, previous == false {
                broadcaster.emit(())
            }
        }
    }

    private let monitor: NWPathMonitor
    private let state = State()

    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [state] path in
            state.update(satisfied: path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "LARP.NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }

    var availableEvents: AsyncStream<Void> {
        state.broadcaster.stream()
    }
}
