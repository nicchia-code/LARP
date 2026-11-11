import SwiftUI

/// A LARP surface. Each one sets its own appearance, so that the system controls inside it draw
/// well whatever the appearance of the Mac: light on paper and white, dark on ink.
enum LARPSurface {
    case paper
    case white
    case ink
    case darkRaised
    case darkCard

    var color: Color {
        switch self {
        case .paper: LARPColor.paper
        case .white: LARPColor.white
        case .ink: LARPColor.ink
        case .darkRaised: LARPColor.darkRaised
        case .darkCard: LARPColor.darkCard
        }
    }

    var isDark: Bool {
        switch self {
        case .paper, .white: false
        case .ink, .darkRaised, .darkCard: true
        }
    }
}

private struct SurfaceModifier: ViewModifier {
    let surface: LARPSurface

    func body(content: Content) -> some View {
        content
            .foregroundStyle(surface.isDark ? LARPColor.textOnDark : LARPColor.ink)
            .tint(surface.isDark ? LARPColor.lime : LARPColor.ink)
            .environment(\.colorScheme, surface.isDark ? .dark : .light)
            .environment(\.larpOnDark, surface.isDark)
            .background(surface.color)
    }
}

extension View {
    /// Fills the view with a LARP surface and sets the appearance of everything inside it.
    func larpSurface(_ surface: LARPSurface) -> some View {
        modifier(SurfaceModifier(surface: surface))
    }

    /// The appearance of a region without a background of its own (inside a card, a button).
    func larpAppearance(dark: Bool) -> some View {
        environment(\.colorScheme, dark ? .dark : .light).environment(\.larpOnDark, dark)
    }
}

private struct OnDarkKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the view sits on a dark LARP surface: components pick their light or dark variant.
    var larpOnDark: Bool {
        get { self[OnDarkKey.self] }
        set { self[OnDarkKey.self] = newValue }
    }
}

/// The 2 px outline of a custom control that has the keyboard focus: lime on dark, ink on light.
private struct FocusOutline: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.isFocused) private var isFocused
    @Environment(\.larpOnDark) private var onDark

    func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius + 2)
                    .strokeBorder(onDark ? LARPColor.lime : LARPColor.ink, lineWidth: 2)
                    .padding(-3)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// No focus ring drawn by the system; the control shows its focus with a 2 px outline.
    func larpFocusOutline(cornerRadius: CGFloat) -> some View {
        focusEffectDisabled().modifier(FocusOutline(cornerRadius: cornerRadius))
    }
}
