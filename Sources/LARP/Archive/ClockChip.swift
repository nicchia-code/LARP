import SwiftUI

/// A time of the call (`mm:ss`) in a JetBrains Mono chip on `#ECECE4`: the time of a bookmark or of a
/// note.
struct ClockChip: View {
    let seconds: TimeInterval

    var body: some View {
        Text(ArchiveFormat.clock(seconds))
            .font(LARPFont.mono(11))
            .foregroundStyle(LARPColor.ink)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(LARPColor.chipNeutral, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// The colour of a row under the pointer on paper and white.
extension LARPColor {
    static let rowHover = Color(hex: 0xF1F1EA)
}

/// The small button that deletes a bookmark or a note; it shows only under the pointer.
struct RowDeleteButton: View {
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(LARPColor.textSecondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.larpPlain)
        .accessibilityLabel(label)
    }
}
