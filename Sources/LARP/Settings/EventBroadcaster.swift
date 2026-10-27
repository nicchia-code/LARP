import Synchronization

/// Delivers every emitted value to all the streams handed out by `stream()`.
/// A stream sees only the values emitted after it was created; it ends when
/// its consumer stops iterating.
final class EventBroadcaster<Element: Sendable>: Sendable {
    private struct Subscribers: Sendable {
        var nextID = 0
        var continuations: [Int: AsyncStream<Element>.Continuation] = [:]
    }

    private let subscribers = Mutex(Subscribers())

    init() {}

    /// A new stream receiving the values emitted from now on.
    func stream() -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream<Element>.makeStream(bufferingPolicy: .unbounded)
        let id = subscribers.withLock { state in
            let id = state.nextID
            state.nextID += 1
            state.continuations[id] = continuation
            return id
        }
        continuation.onTermination = { [weak self] _ in
            self?.subscribers.withLock { _ = $0.continuations.removeValue(forKey: id) }
        }
        return stream
    }

    func emit(_ element: Element) {
        let continuations = subscribers.withLock { Array($0.continuations.values) }
        for continuation in continuations {
            continuation.yield(element)
        }
    }
}
