import AppKit
import SwiftUI

extension Color {
    /// A colour from a 24-bit `0xRRGGBB` value, in sRGB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    /// An opaque colour from a 24-bit `0xRRGGBB` value, in sRGB.
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The fixed palette of LARP (requirements/ui#General): the same with the Mac in light or dark
/// appearance. Every surface sets its own appearance, see `larpSurface(_:)`.
///
/// Lime is never text on light surfaces, and `textMuted` is never text on light surfaces.
enum LARPColor {
    // Surfaces and main text.
    static let ink = Color(hex: Hex.ink)
    static let paper = Color(hex: Hex.paper)
    static let white = Color(hex: Hex.white)
    static let lime = Color(hex: Hex.lime)

    // Text.
    /// Secondary text on light surfaces.
    static let textSecondary = Color(hex: Hex.textSecondary)
    /// Muted text, only on dark surfaces.
    static let textMuted = Color(hex: Hex.textMuted)
    /// Light text on dark surfaces.
    static let textOnDark = Color(hex: Hex.textOnDark)

    // Borders and light fills.
    /// Borders of cards, fields and dividers.
    static let border = Color(hex: Hex.border)
    /// Borders of chips and outline buttons.
    static let chipBorder = Color(hex: Hex.chipBorder)
    static let chipNeutral = Color(hex: Hex.chipNeutral)
    /// Dividers on paper.
    static let dividerLight = Color(hex: Hex.dividerLight)

    // Raised dark surfaces.
    static let darkRaised = Color(hex: Hex.darkRaised)
    /// The selected item of the sidebar.
    static let darkSelected = Color(hex: Hex.darkSelected)
    /// Cards on dark.
    static let darkCard = Color(hex: Hex.darkCard)
    /// Borders and idle bars on dark.
    static let darkBorder = Color(hex: Hex.darkBorder)

    // Accents.
    static let switchOff = Color(hex: Hex.switchOff)
    /// The recording dot.
    static let recording = Color(hex: Hex.recording)
    /// Destructive text.
    static let destructive = Color(hex: Hex.destructive)
    /// The transcript line being heard, on light.
    static let currentLine = Color(hex: Hex.currentLine)

    // Participants.
    static let lilac = Color(hex: Hex.lilac)
    static let peach = Color(hex: Hex.peach)
    static let sky = Color(hex: Hex.sky)

    /// The same colours as `0xRRGGBB`, for AppKit drawing and for tests.
    enum Hex {
        static let ink: UInt32 = 0x121310
        static let paper: UInt32 = 0xFAFAF5
        static let white: UInt32 = 0xFFFFFF
        static let lime: UInt32 = 0xD4F24A
        static let textSecondary: UInt32 = 0x5A5D55
        static let textMuted: UInt32 = 0xA3A69B
        static let textOnDark: UInt32 = 0xE9EAE3
        static let border: UInt32 = 0xE4E4DC
        static let chipBorder: UInt32 = 0xD0D1C8
        static let chipNeutral: UInt32 = 0xECECE4
        static let dividerLight: UInt32 = 0xE9EAE3
        static let darkRaised: UInt32 = 0x1D1F1A
        static let darkSelected: UInt32 = 0x23251F
        static let darkCard: UInt32 = 0x2A2C26
        static let darkBorder: UInt32 = 0x3A3C36
        static let switchOff: UInt32 = 0x8A8D82
        static let recording: UInt32 = 0xFF5A40
        static let destructive: UInt32 = 0xB42A18
        static let currentLine: UInt32 = 0xEEF8B4
        static let lilac: UInt32 = 0xCFC6FF
        static let peach: UInt32 = 0xFFCFAE
        static let sky: UInt32 = 0x9FD8FF
    }
}

/// The colour of each speaker, the same wherever a speaker appears: the avatar, the dot before a
/// line, a waveform bar, the playback timeline.
enum SpeakerPalette {
    /// Participants by number: 1 lime, 2 lilac, 3 peach, 4 sky, then again from lime.
    static let participantColors: [Color] = [LARPColor.lime, LARPColor.lilac, LARPColor.peach, LARPColor.sky]

    /// "Io" is ink on light surfaces and white on dark ones; "Altri" as a whole is `#A3A69B`; a
    /// participant takes the colour of its number (a missing number counts as "Altri").
    static func color(kind: SpeakerKind, participantNumber: Int?, onDark: Bool = false) -> Color {
        switch kind {
        case .me:
            return onDark ? LARPColor.white : LARPColor.ink
        case .others:
            return LARPColor.textMuted
        case .participant:
            guard let number = participantNumber, number >= 1 else { return LARPColor.textMuted }
            return participantColors[(number - 1) % participantColors.count]
        }
    }

    /// The colour of the initial inside an avatar: white on the ink "Io" of a light surface, ink
    /// on everything else (participant colours always carry ink text).
    static func initialColor(kind: SpeakerKind, onDark: Bool = false) -> Color {
        kind == .me && !onDark ? LARPColor.white : LARPColor.ink
    }
}

extension TranscriptLine {
    /// The colour of whoever speaks this line, see `SpeakerPalette`.
    func speakerColor(onDark: Bool = false) -> Color {
        SpeakerPalette.color(kind: speakerKind, participantNumber: participant?.number, onDark: onDark)
    }
}
