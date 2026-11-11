import SwiftUI

/// The field "Trova una parola" of the transcript panel: `#F1F1EA`, radius 16, 32 px high, with a
/// magnifying glass and, while there is text, the count "<n> di <m>" and the up and down arrows that go
/// to the previous and the next found line (`TranscriptFind`).
struct TranscriptFindField: View {
    @Binding var text: String
    let find: TranscriptFind
    let previous: () -> Void
    let next: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(LARPColor.textSecondary)
            TextField(text: $text, prompt: Text("Trova una parola").foregroundStyle(LARPColor.textSecondary)) {
                EmptyView()
            }
            .textFieldStyle(.plain)
            .font(LARPFont.inter(12))
            .foregroundStyle(LARPColor.ink)
            .focused($isFocused)
            // Return goes to the next found line.
            .onSubmit(next)
            if find.isActive {
                let counter = find.counter
                Text(verbatim: L10n.format("%lld di %lld", counter.position, counter.total))
                    .font(LARPFont.mono(11))
                    .foregroundStyle(LARPColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                arrow("chevron.up", label: "Riga trovata precedente", action: previous)
                arrow("chevron.down", label: "Riga trovata successiva", action: next)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(LARPColor.rowHover, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 18).strokeBorder(LARPColor.ink, lineWidth: 2).padding(-3)
            }
        }
        .larpAppearance(dark: false)
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LARPColor.ink)
                .frame(width: 18, height: 24)
        }
        .buttonStyle(.larpPlain)
        .disabled(find.found.isEmpty)
        .accessibilityLabel(label)
    }
}
