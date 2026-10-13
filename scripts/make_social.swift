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

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

// Background
NSGradient(colors: [srgb(0.07, 0.07, 0.11), srgb(0.14, 0.13, 0.22)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)

/// Classic arrow pointer with its tip at `tip` (origin bottom-left), `height` tall.
func pointer(tip: CGPoint, height: CGFloat, fill: [NSColor], outline: NSColor) {
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
    ctx.setShadow(offset: CGSize(width: 0, height: -height * 0.03), blur: height * 0.08,
                  color: NSColor.black.withAlphaComponent(0.45).cgColor)
    outline.setStroke(); path.lineWidth = height * 0.075; path.stroke()
    ctx.restoreGState()
    if fill.count > 1 { NSGradient(colors: fill)!.draw(in: path, angle: -60) } else { fill[0].setFill(); path.fill() }
}

// Text
func text(_ s: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        .draw(at: p)
}
text("BetterPointer", at: CGPoint(x: 80, y: 370), size: 96, weight: .heavy, color: .white)
text("Change your Mac's pointer size and colors", at: CGPoint(x: 84, y: 300), size: 34, weight: .medium, color: srgb(0.82, 0.82, 0.9))
text("live, right from the menu bar.", at: CGPoint(x: 84, y: 256), size: 34, weight: .medium, color: srgb(0.82, 0.82, 0.9))
text("1×–10×  ·  Fill & outline  ·  Custom presets", at: CGPoint(x: 84, y: 150), size: 26, weight: .semibold,
     color: srgb(0.62, 0.6, 0.95))
text("Free & open source for macOS 13+", at: CGPoint(x: 84, y: 105), size: 24, weight: .regular, color: srgb(0.55, 0.55, 0.65))

// Pointers growing in size and style, bottoms aligned
let rainbow = [srgb(1, 0.23, 0.19), srgb(1, 0.58, 0), srgb(1, 0.84, 0), srgb(0.2, 0.82, 0.35), srgb(0, 0.55, 1), srgb(0.69, 0.32, 0.87)]
let base: CGFloat = 150
let styles: [(x: CGFloat, h: CGFloat, fill: [NSColor], outline: NSColor)] = [
    (730, 80, [.black], .white),
    (810, 130, [srgb(1, 0.85, 0)], .black),
    (915, 190, [srgb(1, 0.2, 0.25)], .white),
    (1050, 320, rainbow, srgb(0.08, 0.08, 0.1)),
]
for st in styles { pointer(tip: CGPoint(x: st.x, y: base + st.h), height: st.h, fill: st.fill, outline: st.outline) }

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/social-preview.png"))
