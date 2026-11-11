import AppKit
import SwiftUI

/// The LARP mark: a rounded square (radius 30 % of its side) with four vertical bars with round
/// ends on a 24-unit grid, at x 6, 10, 14 and 18, from y 10 to 14, 6 to 18, 8 to 16 and 11 to 13,
/// stroke 2.6.
enum LarpMarkGeometry {
    /// The bars as (x, top, bottom) on the 24-unit grid.
    static let bars: [(x: CGFloat, top: CGFloat, bottom: CGFloat)] = [
        (6, 10, 14), (10, 6, 18), (14, 8, 16), (18, 11, 13),
    ]
    static let grid: CGFloat = 24
    static let strokeWidth: CGFloat = 2.6
    static let cornerRatio: CGFloat = 0.3

    /// The bars drawn in a square of `side`, as one path with round ends.
    static func barsPath(in rect: CGRect) -> CGPath {
        let scale = rect.width / grid
        let path = CGMutablePath()
        for bar in bars {
            let x = rect.minX + bar.x * scale
            path.move(to: CGPoint(x: x, y: rect.minY + bar.top * scale))
            path.addLine(to: CGPoint(x: x, y: rect.minY + bar.bottom * scale))
        }
        return path
    }

    static func strokedBars(in rect: CGRect) -> CGPath {
        barsPath(in: rect).copy(
            strokingWithWidth: strokeWidth * rect.width / grid, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }
}

/// The mark as a view: the lime square with ink bars (the mark beside the "LARP" wordmark), or the
/// ink square with lime bars.
struct LarpMark: View {
    enum Style {
        case limeSquare
        case inkSquare
    }

    var size: CGFloat = 30
    var style: Style = .limeSquare

    var body: some View {
        Canvas { context, canvas in
            let rect = CGRect(origin: .zero, size: canvas)
            let square = Path(roundedRect: rect, cornerRadius: canvas.width * LarpMarkGeometry.cornerRatio)
            context.fill(square, with: .color(style == .limeSquare ? LARPColor.lime : LARPColor.ink))
            context.fill(
                Path(LarpMarkGeometry.strokedBars(in: rect)),
                with: .color(style == .limeSquare ? LARPColor.ink : LARPColor.lime))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The images of the mark drawn in code.
enum LarpMarkImage {
    /// The menu bar icon: a coloured image (never a template), an ink square with lime bars, the
    /// same with a light or a dark menu bar.
    static func menuBarIcon(side: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let square = CGPath(
                roundedRect: rect, cornerWidth: rect.width * LarpMarkGeometry.cornerRatio,
                cornerHeight: rect.height * LarpMarkGeometry.cornerRatio, transform: nil)
            context.setFillColor(NSColor(hex: LARPColor.Hex.ink).cgColor)
            context.addPath(square)
            context.fillPath()
            context.setFillColor(NSColor(hex: LARPColor.Hex.lime).cgColor)
            context.addPath(LarpMarkGeometry.strokedBars(in: rect))
            context.fillPath()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// A round dot of `color`, a coloured image: the red dot of a recording.
    static func dot(_ color: NSColor, diameter: CGFloat = 10) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
