import SwiftUI

/// The kinds of button of the Style Guide, 40 px high, radius 10, 13 px text.
enum LARPButtonKind {
    /// Lime with ink semibold text.
    case primary
    /// Ink with lime text.
    case dark
    /// White with a `#D0D1C8` border.
    case outline
    /// White with a `#D0D1C8` border and `#B42A18` text.
    case destructive
    /// Transparent with a dark border and light text: on dark surfaces.
    case outlineOnDark
    /// White with ink text: on dark surfaces.
    case white
}

struct LARPButtonStyle: ButtonStyle {
    var kind: LARPButtonKind = .outline
    /// Full width, for the buttons of the popover and of the proposal.
    var fullWidth = false
    var height: CGFloat = 40
    var radius: CGFloat = 10
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(kind == .primary ? LARPFont.inter(13, .semibold) : LARPFont.inter(13, .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(background, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .larpFocusOutline(cornerRadius: radius)
    }

    private var textColor: Color {
        switch kind {
        case .primary, .white: LARPColor.ink
        case .dark: LARPColor.lime
        case .outline: LARPColor.ink
        case .destructive: LARPColor.destructive
        case .outlineOnDark: LARPColor.textOnDark
        }
    }

    private var background: Color {
        switch kind {
        case .primary: LARPColor.lime
        case .dark: LARPColor.ink
        case .outline, .destructive, .white: LARPColor.white
        case .outlineOnDark: .clear
        }
    }

    private var border: Color? {
        switch kind {
        case .outline, .destructive: LARPColor.chipBorder
        case .outlineOnDark: LARPColor.darkBorder
        case .primary, .dark, .white: nil
        }
    }
}

/// A text link: underlined with an offset of 3 px, 13 px.
struct LARPLinkButtonStyle: ButtonStyle {
    var color: Color? = nil
    @Environment(\.larpOnDark) private var onDark
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let tint = color ?? (onDark ? LARPColor.textOnDark : LARPColor.ink)
        configuration.label
            .font(LARPFont.inter(13))
            .foregroundStyle(tint)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(tint).frame(height: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Rectangle())
            .larpFocusOutline(cornerRadius: 2)
    }
}

/// A button with no look of its own besides the focus outline and the pressed state: sidebar
/// items, rows, cards.
struct LARPPlainButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(Rectangle())
            .larpFocusOutline(cornerRadius: cornerRadius)
    }
}

extension ButtonStyle where Self == LARPButtonStyle {
    static func larp(_ kind: LARPButtonKind = .outline, fullWidth: Bool = false) -> LARPButtonStyle {
        LARPButtonStyle(kind: kind, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == LARPLinkButtonStyle {
    static var larpLink: LARPLinkButtonStyle { LARPLinkButtonStyle() }
}

extension ButtonStyle where Self == LARPPlainButtonStyle {
    static var larpPlain: LARPPlainButtonStyle { LARPPlainButtonStyle() }
}
