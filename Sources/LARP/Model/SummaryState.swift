import Foundation

/// State of the summary of a call, separate from `CallState`.
enum SummaryState: String, Codable, CaseIterable, Sendable {
    /// The call has no summary.
    case none
    /// The assistant is writing the summary.
    case writing
    /// Writing failed; it will be tried again.
    case awaitingRetry
    /// The call holds its summary.
    case written
}
