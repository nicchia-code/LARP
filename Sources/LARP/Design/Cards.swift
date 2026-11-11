import SwiftUI

/// The kinds of card of the Style Guide.
enum LARPCardStyle {
    /// White, a 1 px `#E4E4DC` border.
    case light
    /// `#2A2C26` on dark.
    case dark
    /// `#1D1F1A` on dark.
    case darkRaised
}

private struct CardModifier: ViewModifier {
    let style: LARPCardStyle
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                if style == .light {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(LARPColor.border, lineWidth: 1)
                }
            }
            .larpAppearance(dark: style != .light)
    }

    private var fill: Color {
        switch style {
        case .light: LARPColor.white
        case .dark: LARPColor.darkCard
        case .darkRaised: LARPColor.darkRaised
        }
    }
}

extension View {
    /// A card, radius 18 and 18–24 px of padding.
    func larpCard(_ style: LARPCardStyle = .light, padding: CGFloat = 20, radius: CGFloat = 18) -> some View {
        modifier(CardModifier(style: style, padding: padding, radius: radius))
    }
}

/// A 1 px divider: `#E9EAE3` on paper, `#2A2C26` on dark.
struct LARPDivider: View {
    @Environment(\.larpOnDark) private var onDark

    var body: some View {
        Rectangle()
            .fill(onDark ? LARPColor.darkCard : LARPColor.dividerLight)
            .frame(height: 1)
    }
}

/// The dark sidebar, 210 px wide, with room at the top for the buttons of the window.
struct LARPSidebar<Content: View>: View {
    static var width: CGFloat { 210 }
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.top, 52)
            .padding(.bottom, 16)
            .frame(width: Self.width)
            .frame(maxHeight: .infinity, alignment: .top)
            .larpSurface(.ink)
    }
}
