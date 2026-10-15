// Spike: a giant pointer drawn in a click-through overlay window that follows the mouse.
import AppKit

let scale: CGFloat = CommandLine.arguments.count > 1 ? CGFloat(Double(CommandLine.arguments[1]) ?? 30) : 30
let seconds = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 8 : 8
let height = 16 * scale // the 1× arrow is ~16pt tall

final class PointerView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let unit: [(CGFloat, CGFloat)] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
        let s = height / 0.93, pad = height * 0.06
        let path = NSBezierPath()
        for (i, p) in unit.enumerated() {
            let pt = NSPoint(x: pad + p.0 * s, y: pad + p.1 * s)
            i == 0 ? path.move(to: pt) : path.line(to: pt)
        }
        path.close(); path.lineJoinStyle = .round
        NSColor.white.setStroke(); path.lineWidth = height * 0.075; path.stroke()
        NSColor(srgbRed: 1, green: 0.15, blue: 0.1, alpha: 1).setFill(); path.fill()
    }
}

@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSSetConnectionProperty") func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let pad = height * 0.06
let size = NSSize(width: height * 0.7 + pad * 2, height: height + pad * 2)
let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.ignoresMouseEvents = true
window.level = .screenSaver
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
window.contentView = PointerView(frame: NSRect(origin: .zero, size: size))
window.orderFrontRegardless()

// Hide the real pointer even though we're a background app (restored on exit by the window server).
let cid = CGSMainConnectionID()
print("SetsCursorInBackground err=\(CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue))")
print("hide err=\(CGDisplayHideCursor(CGMainDisplayID()).rawValue)")

// Follow the mouse every frame; the arrow's tip sits on the hotspot.
let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { _ in
    let m = NSEvent.mouseLocation
    window.setFrameOrigin(NSPoint(x: m.x - pad, y: m.y - size.height + pad))
}
RunLoop.main.add(timer, forMode: .common)
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
    CGDisplayShowCursor(CGMainDisplayID())
    exit(0)
}
app.run()
