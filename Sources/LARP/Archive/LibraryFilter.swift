import Foundation

/// Which calls the filter chips above the cards show (`user.FILTER_BY_APP`).
enum AppFilter: Hashable, Sendable {
    /// "Tutte": every call.
    case all
    /// The calls tied to this call app.
    case app(String)
    /// "Manuali": the calls recorded by hand.
    case manual
    /// "Importate": the calls made by importing an audio file.
    case imported
}

/// The filter chips of the library and what they show. Pure, so the rules can be tested.
enum LibraryFilter {
    /// The chips for `calls`, the calls of the archive or of the folder shown: "Tutte", then one per
    /// call app that at least one of them is tied to, in alphabetical order, then "Manuali" when one
    /// was recorded by hand and "Importate" when one was imported.
    static func chips(for calls: [Call]) -> [AppFilter] {
        let apps = Set(calls.compactMap { $0.isImported ? nil : $0.callAppName })
            .sorted { $0.compare($1, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedAscending }
        var chips: [AppFilter] = [.all]
        chips += apps.map { AppFilter.app($0) }
        if calls.contains(where: isManual) { chips.append(.manual) }
        if calls.contains(where: \.isImported) { chips.append(.imported) }
        return chips
    }

    /// Whether `call` is shown by `filter`.
    static func matches(_ call: Call, _ filter: AppFilter) -> Bool {
        switch filter {
        case .all: true
        case .app(let name): !call.isImported && call.callAppName == name
        case .manual: isManual(call)
        case .imported: call.isImported
        }
    }

    /// The calls of `calls` that `filter` shows.
    static func apply(_ filter: AppFilter, to calls: [Call]) -> [Call] {
        filter == .all ? calls : calls.filter { matches($0, filter) }
    }

    /// `filter` when one of the chips offers it, otherwise "Tutte": a filter whose call app has no
    /// call any more goes back to "Tutte".
    static func resolved(_ filter: AppFilter, among calls: [Call]) -> AppFilter {
        chips(for: calls).contains(filter) ? filter : .all
    }

    /// A call recorded by hand: not imported and tied to no call app.
    private static func isManual(_ call: Call) -> Bool {
        !call.isImported && call.callAppName == nil
    }
}

extension Call {
    /// The call app as a card and the page of a call show it: "Importata" for an imported file,
    /// "Manuale" for a recording started by hand.
    func appLabel(language: AppLanguage = .current) -> String {
        if isImported { return L10n.string("Importata", language: language) }
        return callAppName ?? L10n.string("Manuale", language: language)
    }
}
