import SwiftUI

@main
struct BetterPointerApp: App {
    @StateObject private var store = PointerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(store)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// The app icon's rainbow pointer. Full color on purpose: a monochrome arrow is
    /// easy to mistake for the real pointer sitting in the menu bar.
    private static let menuBarIcon: NSImage = {
        let height: CGFloat = 16
        let image = NSImage(size: NSSize(width: 12, height: 18), flipped: true) { _ in
            let unit: [(CGFloat, CGFloat)] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
            let scale = height / 0.93
            let path = NSBezierPath()
            for (i, p) in unit.enumerated() {
                let point = NSPoint(x: 1.5 + p.0 * scale, y: 1 + p.1 * scale)
                i == 0 ? path.move(to: point) : path.line(to: point)
            }
            path.close()
            path.lineJoinStyle = .round
            let rainbow = [(1.0, 0.23, 0.19), (1.0, 0.58, 0.0), (1.0, 0.84, 0.0), (0.2, 0.82, 0.35), (0.0, 0.55, 1.0), (0.69, 0.32, 0.87)]
                .map { NSColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1) }
            NSColor(white: 0.1, alpha: 0.9).setStroke()
            path.lineWidth = 1.2
            path.stroke()
            NSGradient(colors: rainbow)!.draw(in: path, angle: 60)
            return true
        }
        return image
    }()
}
