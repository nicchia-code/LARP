import SwiftUI

/// An action item of a summary, as the page of the call and the "Azioni" view of the library draw it:
/// a white row (radius 10, `#E4E4DC` border) with an 18 px square tick (ink filled with a white check
/// when done), its text in 13 px (struck through in `#5A5D55` on `#F1F1EA` when done) and, on the right,
/// the avatar of its owner with "<name> · <due>" in 12 px `#5A5D55`. The tick is `user.TOGGLE_ACTION_ITEM`;
/// with `open` the rest of the row opens the call (`user.SELECT_CALL`).
struct SummaryActionRow: View {
    let action: SummaryContent.Action
    let toggle: () -> Void
    var open: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            tick
            if let open {
                Button(action: open) { content }
                    .buttonStyle(.larpPlain)
            } else {
                content
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(action.isDone ? LARPColor.rowHover : LARPColor.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LARPColor.border, lineWidth: 1) }
    }

    private var tick: some View {
        Button(action: toggle) {
            RoundedRectangle(cornerRadius: 4)
                .fill(action.isDone ? LARPColor.ink : LARPColor.white)
                .overlay {
                    if action.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LARPColor.white)
                    } else {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(LARPColor.chipBorder, lineWidth: 1.5)
                    }
                }
                .frame(width: 18, height: 18)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.larpPlain)
        .accessibilityLabel(LocalizedStringKey(action.isDone ? "Azione fatta" : "Azione da fare"))
        .accessibilityValue(action.text)
        .accessibilityAddTraits(.isToggle)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(verbatim: action.text)
                .font(LARPFont.inter(13))
                .strikethrough(action.isDone)
                .foregroundStyle(action.isDone ? LARPColor.textSecondary : LARPColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            owner
        }
        .contentShape(Rectangle())
    }

    /// The avatar of the owner with "<name> · <due>"; the due alone when there is no owner.
    @ViewBuilder
    private var owner: some View {
        let label = [action.owner, action.due].compactMap { $0 }.joined(separator: " · ")
        if !label.isEmpty {
            HStack(spacing: 8) {
                if action.owner != nil {
                    LARPAvatar(
                        initial: action.ownerInitial ?? "", kind: action.ownerKind,
                        participantNumber: action.ownerParticipant,
                        ring: action.isDone ? LARPColor.rowHover : LARPColor.white)
                }
                Text(verbatim: label)
                    .font(LARPFont.inter(12))
                    .foregroundStyle(LARPColor.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
