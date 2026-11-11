import Foundation

/// The action items of one call as the "Azioni" view of the library lists them.
struct ActionGroup: Identifiable {
    let call: Call
    /// The items not done first, then the done ones, each group in the order of the summary.
    let actions: [SummaryContent.Action]

    var id: UUID { call.id }
}

/// What the "Azioni" view of the library lists (`main-window/Actions view`).
enum ActionListing {
    /// The action items of the summaries of the calls that match the search, grouped by call, the most
    /// recent call first; within a call the items not done first, then the done ones, each in the order
    /// of the summary. A call without action items is left out.
    static func groups(of calls: [Call], query: String, language: AppLanguage = .current) -> [ActionGroup] {
        CallSearch.filter(calls, query: query)
            .sorted { $0.startedAt != $1.startedAt ? $0.startedAt > $1.startedAt : $0.id.uuidString < $1.id.uuidString }
            .compactMap { call in
                guard let actions = SummaryContent(call: call, language: language)?.actions, !actions.isEmpty else { return nil }
                return ActionGroup(call: call, actions: actions.filter { !$0.isDone } + actions.filter(\.isDone))
            }
    }
}
