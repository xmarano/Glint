import AppKit
import SwiftUI

/// Small-size companion to the dimensional app icon. A vector silhouette keeps
/// the menu bar sharp at either display scale and lets macOS apply its own tint.
enum GlintBrand {
    static func path(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 98, y: 2))
        path.addCurve(to: CGPoint(x: 82, y: 82),
                      control1: CGPoint(x: 72, y: 42), control2: CGPoint(x: 62, y: 48))
        path.addCurve(to: CGPoint(x: 2, y: 98),
                      control1: CGPoint(x: 52, y: 57), control2: CGPoint(x: 44, y: 67))
        path.addCurve(to: CGPoint(x: 23, y: 22),
                      control1: CGPoint(x: 31, y: 56), control2: CGPoint(x: 36, y: 48))
        path.addCurve(to: CGPoint(x: 98, y: 2),
                      control1: CGPoint(x: 44, y: 52), control2: CGPoint(x: 60, y: 36))
        path.closeSubpath()
        let side = min(rect.width, rect.height)
        var transform = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
        transform = transform.scaledBy(x: side / 100, y: side / 100)
        return path.copy(using: &transform)!
    }

    @MainActor static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(path(in: rect.insetBy(dx: 1, dy: 1)))
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Glint"
        return image
    }
}

struct GlintMark: View {
    var body: some View {
        MarkShape()
            .fill(LinearGradient(colors: [Color(red: 1, green: 0.89, blue: 0.64),
                                           Color(red: 1, green: 0.68, blue: 0.27),
                                           Color(red: 1, green: 0.48, blue: 0.20)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .accessibilityHidden(true)
    }
    private struct MarkShape: Shape {
        func path(in rect: CGRect) -> Path { Path(GlintBrand.path(in: rect)) }
    }
}
