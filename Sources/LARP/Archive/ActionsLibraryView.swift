import SwiftUI

/// The "Azioni" view of the library (`main-window/Actions view`): one white card per call with action
/// items, with the eyebrow of its day, time and call app, its title and one row per item as on the page of
/// the call. Ticking an item is the same as on the page of its call (`user.TOGGLE_ACTION_ITEM`); a click on
/// the call or outside the tick of an item opens the page of the call (`user.SELECT_CALL`). Without action
/// items the view says "Nessuna azione".
struct ActionsLibraryView: View {
    let groups: [ActionGroup]
    /// `user.SELECT_CALL`.
    let select: (Call) -> Void
    @Environment(CallLifecycle.self) private var lifecycle

    var body: some View {
        if groups.isEmpty {
            EmptyText(text: "Nessuna azione")
        } else {
            VStack(spacing: 16) {
                ForEach(groups) { group in
                    ActionGroupCard(
                        group: group,
                        toggle: { lifecycle.toggleActionItem(of: group.call, at: $0.index) },
                        select: { select(group.call) })
                }
            }
        }
    }
}

private struct ActionGroupCard: View {
    let group: ActionGroup
    let toggle: (SummaryContent.Action) -> Void
    let select: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(verbatim: "\(ArchiveFormat.cardDayAndTime(group.call.startedAt)) · \(group.call.appLabel())")
                    Text(group.call.displayTitle)
                        .larpText(.cardTitle)
                        .foregroundStyle(LARPColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.larpPlain)
            VStack(spacing: 8) {
                ForEach(group.actions, id: \.index) { action in
                    SummaryActionRow(action: action, toggle: { toggle(action) }, open: select)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .larpCard(.light, padding: 20, radius: 18)
    }
}
