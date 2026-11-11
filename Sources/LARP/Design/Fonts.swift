import CoreText
import Foundation
import SwiftUI
import os

/// The three bundled fonts (requirements/ui#General): Inter for every text, Bricolage Grotesque for
/// display and JetBrains Mono for eyebrows, times and shortcuts.
enum LARPFont {
    enum Weight: Sendable {
        case regular, medium, semibold, bold
    }

    /// Inter, 400 / 500 / 600; bold maps to 600.
    static func inter(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name =
            switch weight {
            case .regular: "Inter-Regular"
            case .medium: "Inter-Medium"
            case .semibold, .bold: "Inter-SemiBold"
            }
        return .custom(name, fixedSize: size)
    }

    /// Bricolage Grotesque: the optical size of the big titles (from 36 px) for bold, the text cut
    /// below it.
    static func display(_ size: CGFloat, _ weight: Weight = .bold) -> Font {
        let name =
            switch weight {
            case .bold where size >= 36: "BricolageGrotesque96pt-Bold"
            case .bold: "BricolageGrotesque-Bold"
            case .regular, .medium, .semibold: "BricolageGrotesque-SemiBold"
            }
        return .custom(name, fixedSize: size)
    }

    /// JetBrains Mono Medium.
    static func mono(_ size: CGFloat = 11) -> Font {
        .custom("JetBrainsMono-Medium", fixedSize: size)
    }

    private static let logger = Logger(subsystem: "com.larp.LARP", category: "fonts")

    /// Registers every font file of the app bundle for the process. Called once when the app
    /// starts; registering again is harmless.
    static func register(bundle: Bundle = .main) {
        let urls = ["ttf", "otf"].flatMap { bundle.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let alreadyRegistered =
                    (error?.takeRetainedValue() as Error? as NSError?)?.code == CTFontManagerError.alreadyRegistered.rawValue
                if !alreadyRegistered {
                    logger.error("Registering \(url.lastPathComponent, privacy: .public) failed")
                }
            }
        }
    }
}

/// A text style of the Style Guide: font, tracking, line height and case.
struct LARPTextStyle: Sendable {
    let font: Font
    /// In points, already scaled from the em values of the Style Guide.
    let tracking: CGFloat
    /// Extra space between lines, in points (negative for a line height of 1).
    let lineSpacing: CGFloat
    let uppercased: Bool

    private init(font: Font, tracking: CGFloat = 0, lineSpacing: CGFloat = 0, uppercased: Bool = false) {
        self.font = font
        self.tracking = tracking
        self.lineSpacing = lineSpacing
        self.uppercased = uppercased
    }

    /// 44 px bold, −0.03 em, line height 1: the title of a page.
    static let pageTitle = LARPTextStyle(font: LARPFont.display(44), tracking: -0.03 * 44, lineSpacing: -0.2 * 44)
    /// 56 px bold, −0.03 em, line height 1: the title of a call page.
    static let callTitle = LARPTextStyle(font: LARPFont.display(56), tracking: -0.03 * 56, lineSpacing: -0.2 * 56)
    /// 19 px semibold, −0.01 em: the title of a card.
    static let cardTitle = LARPTextStyle(font: LARPFont.display(19, .semibold), tracking: -0.01 * 19)
    /// 22 px semibold, −0.01 em: the title of a proposal or of a recording.
    static let proposalTitle = LARPTextStyle(font: LARPFont.display(22, .semibold), tracking: -0.01 * 22)
    /// 20–24 px semibold: section and card headings.
    static let sectionHeading = LARPTextStyle(font: LARPFont.display(22, .semibold), tracking: -0.01 * 22)
    /// 20 px bold: the "LARP" wordmark.
    static let wordmark = LARPTextStyle(font: LARPFont.display(20, .bold))
    /// 13 px body.
    static let body = LARPTextStyle(font: LARPFont.inter(13))
    static let bodyMedium = LARPTextStyle(font: LARPFont.inter(13, .medium))
    static let bodySemibold = LARPTextStyle(font: LARPFont.inter(13, .semibold))
    /// 12 px secondary.
    static let secondary = LARPTextStyle(font: LARPFont.inter(12))
    /// 11 px small.
    static let small = LARPTextStyle(font: LARPFont.inter(11))
    /// 10 px small.
    static let tiny = LARPTextStyle(font: LARPFont.inter(10, .semibold))
    /// JetBrains Mono 11 px, upper case, tracking 0.08 em: the lines above titles and sections.
    static let eyebrow = LARPTextStyle(font: LARPFont.mono(11), tracking: 0.08 * 11, uppercased: true)
    /// JetBrains Mono 11 px for times, durations, timestamps and shortcuts.
    static let mono = LARPTextStyle(font: LARPFont.mono(11), tracking: 0.02 * 11)
}

extension View {
    /// Applies a text style: font, tracking and line height; upper case is for `Eyebrow`.
    func larpText(_ style: LARPTextStyle) -> some View {
        font(style.font).tracking(style.tracking).lineSpacing(style.lineSpacing)
    }
}
