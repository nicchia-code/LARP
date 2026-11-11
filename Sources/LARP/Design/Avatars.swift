import SwiftUI

/// A round avatar, 24 px, with a 2 px ring of the colour of the surface and the initial in 10 px
/// semibold.
struct LARPAvatar: View {
    let initial: String
    let fill: Color
    let initialColor: Color
    /// The colour of the surface the avatar sits on.
    let ring: Color
    var size: CGFloat = 24

    /// The avatar of a speaker: the colour of the speaker (`SpeakerPalette`).
    init(initial: String, kind: SpeakerKind, participantNumber: Int?, onDark: Bool = false, ring: Color, size: CGFloat = 24) {
        self.initial = initial
        self.fill = SpeakerPalette.color(kind: kind, participantNumber: participantNumber, onDark: onDark)
        self.initialColor = SpeakerPalette.initialColor(kind: kind, onDark: onDark)
        self.ring = ring
        self.size = size
    }

    var body: some View {
        Text(initial)
            .font(LARPFont.inter(10, .semibold))
            .foregroundStyle(initialColor)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay { Circle().strokeBorder(ring, lineWidth: 2) }
    }
}

/// A row of avatars overlapping by 6 px.
struct LARPAvatarStack: View {
    struct Item: Identifiable {
        let id: String
        let initial: String
        let kind: SpeakerKind
        let participantNumber: Int?
    }

    let items: [Item]
    var onDark = false
    /// The colour of the surface under the avatars.
    var ring: Color = LARPColor.white

    var body: some View {
        HStack(spacing: -6) {
            ForEach(items) { item in
                LARPAvatar(
                    initial: item.initial, kind: item.kind, participantNumber: item.participantNumber,
                    onDark: onDark, ring: ring)
            }
        }
    }
}

/// The small line above a title or a section: JetBrains Mono 11 px, upper case, tracking 0.08 em;
/// `#5A5D55` on light and `#A3A69B` on dark.
struct Eyebrow: View {
    let text: Text
    @Environment(\.larpOnDark) private var onDark

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    init(verbatim string: String) {
        text = Text(verbatim: string)
    }

    var body: some View {
        text
            .textCase(.uppercase)
            .font(LARPFont.mono(11))
            .tracking(0.08 * 11)
            .foregroundStyle(onDark ? LARPColor.textMuted : LARPColor.textSecondary)
            .lineLimit(1)
    }
}

/// A keyboard shortcut: JetBrains Mono 11 px, in a small ink box with lime text on light
/// surfaces, or plain in the colour given (on a lime button).
struct ShortcutKeys: View {
    enum Style {
        case box
        case plain(Color)
    }

    let text: String
    var style: Style = .box

    var body: some View {
        switch style {
        case .box:
            Text(verbatim: text)
                .font(LARPFont.mono(11))
                .foregroundStyle(LARPColor.lime)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 5))
        case .plain(let color):
            Text(verbatim: text)
                .font(LARPFont.mono(11))
                .foregroundStyle(color)
        }
    }
}
