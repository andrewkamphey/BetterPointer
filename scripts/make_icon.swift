// Draws the app icon and writes Resources/AppIcon.icns.
// Run: swift scripts/make_icon.swift
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: size / 1024, y: size / 1024)
    // Flip so y grows downward, like the pointer's coordinates.
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)

    // A single rainbow pointer on a transparent background.
    let pts: [CGPoint] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
        .map { CGPoint(x: 300 + $0.0 * 780, y: 150 + $0.1 * 780) }
    let arrow = NSBezierPath()
    arrow.move(to: pts[0]); pts.dropFirst().forEach { arrow.line(to: $0) }; arrow.close()
    arrow.lineJoinStyle = .round

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 36, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor(white: 0.1, alpha: 1).setStroke(); arrow.lineWidth = 56; arrow.stroke()
    ctx.restoreGState()

    let rainbow = [(1.0, 0.23, 0.19), (1.0, 0.58, 0.0), (1.0, 0.84, 0.0), (0.2, 0.82, 0.35), (0.0, 0.55, 1.0), (0.69, 0.32, 0.87)]
        .map { NSColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1) }
    NSGradient(colors: rainbow)!.draw(in: arrow, angle: 60)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
