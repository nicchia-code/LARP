import SwiftUI

/// A text field: white, 40 px high, radius 10, 1 px `#E4E4DC` border.
struct LARPTextField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    var onSubmit: () -> Void = {}
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(text: $text, prompt: Text(prompt).foregroundStyle(LARPColor.textSecondary)) { EmptyView() }
            .textFieldStyle(.plain)
            .font(LARPFont.inter(13))
            .foregroundStyle(LARPColor.ink)
            .focused($isFocused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .larpField(radius: 10, isFocused: isFocused)
    }
}

/// The search field: white, 40 px high, radius 20, a magnifying glass.
struct LARPSearchField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(LARPColor.textSecondary)
            TextField(text: $text, prompt: Text(prompt).foregroundStyle(LARPColor.textSecondary)) { EmptyView() }
                .textFieldStyle(.plain)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.ink)
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .larpField(radius: 20, isFocused: isFocused)
    }
}

extension View {
    /// The white box with a 1 px border of a field; focused, a 2 px ink outline.
    func larpField(radius: CGFloat, isFocused: Bool = false) -> some View {
        background(LARPColor.white, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius).strokeBorder(LARPColor.border, lineWidth: 1)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: radius + 2).strokeBorder(LARPColor.ink, lineWidth: 2).padding(-3)
                }
            }
            .larpAppearance(dark: false)
    }
}

/// The box of a choice from a list: bordered, radius 8, the current value and a chevron. On dark
/// it is `#2A2C26` with a dark border.
struct LARPChoiceBox<Items: View>: View {
    let value: String
    var minWidth: CGFloat? = nil
    @ViewBuilder let items: Items
    @Environment(\.larpOnDark) private var onDark

    var body: some View {
        Menu {
            items
        } label: {
            HStack(spacing: 8) {
                Text(value)
                    .font(LARPFont.inter(13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(onDark ? LARPColor.textOnDark : LARPColor.ink)
            .padding(.horizontal, 12)
            .frame(minWidth: minWidth, minHeight: 34)
            .background(onDark ? LARPColor.darkRaised : LARPColor.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(onDark ? LARPColor.darkBorder : LARPColor.chipBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.larpPlain)
    }
}
