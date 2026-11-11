import SwiftUI

/// A filter chip, 32 px high, radius 16, 12 px text: selected is ink with lime text, otherwise
/// transparent with a `#D0D1C8` border.
struct LARPChip: View {
    let title: LocalizedStringKey
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LARPFont.inter(12, isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? LARPColor.lime : LARPColor.ink)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(isSelected ? LARPColor.ink : .clear, in: Capsule())
                .overlay {
                    if !isSelected { Capsule().strokeBorder(LARPColor.chipBorder, lineWidth: 1) }
                }
        }
        .buttonStyle(.larpPlain)
        .larpFocusOutline(cornerRadius: 16)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A status chip, 24 px high, radius 12.
struct LARPStatusChip: View {
    enum Kind {
        /// Lime: the transcription is complete, an open count.
        case done
        /// `#ECECE4`: work in progress.
        case neutral
    }

    let text: String
    var kind: Kind = .neutral

    var body: some View {
        Text(text)
            .font(LARPFont.inter(12, .medium))
            .foregroundStyle(LARPColor.ink)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(kind == .done ? LARPColor.lime : LARPColor.chipNeutral, in: Capsule())
    }
}
