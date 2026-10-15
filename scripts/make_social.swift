// Draws the GitHub social preview (1280×640) to docs/social-preview.png.
// Run: swift scripts/make_social.swift
import AppKit

let W: CGFloat = 1280, H: CGFloat = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

// Background
NSGradient(colors: [srgb(0.07, 0.07, 0.11), srgb(0.13, 0.16, 0.32)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

/// Classic arrow pointer with its tip at `tip` (origin bottom-left), `height` tall.
func pointer(tip: CGPoint, height: CGFloat, fill: NSColor, outline: NSColor) {
    let unit: [CGPoint] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
        .map { CGPoint(x: $0.0, y: $0.1) }
    let s = height / 0.93
    let path = NSBezierPath()
    for (i, p) in unit.enumerated() {
        let q = CGPoint(x: tip.x + p.x * s, y: tip.y - p.y * s)
        i == 0 ? path.move(to: q) : path.line(to: q)
    }
    path.close()
    path.lineJoinStyle = .round
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -height * 0.03), blur: height * 0.1,
                  color: NSColor.black.withAlphaComponent(0.5).cgColor)
    outline.setStroke(); path.lineWidth = height * 0.075; path.stroke()
    ctx.restoreGState()
    fill.setFill(); path.fill()
}

func text(_ s: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        .draw(at: p)
}
text("Where's", at: CGPoint(x: 70, y: 455), size: 104, weight: .heavy, color: .white)
text("My Mouse?", at: CGPoint(x: 70, y: 345), size: 104, weight: .heavy, color: .white)
text("Make your Mac's pointer impossible to miss.", at: CGPoint(x: 76, y: 270), size: 32, weight: .semibold, color: srgb(0.88, 0.88, 0.95))
text("For screen recordings, demos & video calls.", at: CGPoint(x: 76, y: 215), size: 27, weight: .semibold,
     color: srgb(0.45, 0.65, 1))
text("Up to 30× · any color · presets per app", at: CGPoint(x: 76, y: 170), size: 23, weight: .regular,
     color: srgb(0.65, 0.65, 0.75))
text("Free & open source for macOS 13+", at: CGPoint(x: 76, y: 90), size: 22, weight: .medium, color: srgb(0.5, 0.5, 0.6))

// The real menu, rendered by scripts/snapshot-menu.sh
let menu = NSImage(contentsOfFile: "docs/menu-dark.png")!
let menuH: CGFloat = 590
let menuW = menuH * menu.size.width / menu.size.height
let menuRect = NSRect(x: 850, y: (H - menuH) / 2, width: menuW, height: menuH)
let clip = NSBezierPath(roundedRect: menuRect, xRadius: 14, yRadius: 14)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 40, color: NSColor.black.withAlphaComponent(0.6).cgColor)
srgb(0.18, 0.18, 0.2).setFill(); clip.fill()
ctx.restoreGState()
ctx.saveGState()
clip.addClip()
menu.draw(in: menuRect)
ctx.restoreGState()
srgb(1, 1, 1, 0.12).setStroke(); clip.lineWidth = 1.5; clip.stroke()

// Big pointer in the "Recording" preset's colors, tapping its row
let rowY = menuRect.maxY - menuH * (333.0 / 1886.0)
pointer(tip: CGPoint(x: menuRect.minX + menuW * 0.62, y: rowY - 4), height: 170, fill: srgb(0, 0.45, 1), outline: .white)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/social-preview.png"))
