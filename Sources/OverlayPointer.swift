import AppKit

@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSSetConnectionProperty") private func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// Draws a pointer bigger than the window server allows (16× and up) in a
/// click-through window that follows the mouse, with the real pointer hidden.
///
/// Always an arrow: it doesn't change to the hand or text cursor. The window
/// server shows the real pointer again if the app quits or crashes.
final class OverlayPointer {
    static let shared = OverlayPointer()

    private(set) var isActive = false
    private(set) var size: Double = 1
    private var window: NSWindow?
    private var view: ArrowView?
    private var timer: Timer?

    func show(size: Double, fill: RGBA, outline: RGBA) {
        self.size = size
        let height = 16 * CGFloat(size) // the 1× arrow is ~16pt tall
        let pad = ArrowView.padding(for: height)
        let frameSize = NSSize(width: height * 0.62 + pad * 2, height: height + pad * 2)

        if window == nil { makeWindow() }
        guard let window, let view else { return }
        view.arrowHeight = height
        view.fill = fill.nsColor
        view.outline = outline.nsColor
        window.setContentSize(frameSize)
        view.frame = NSRect(origin: .zero, size: frameSize)
        view.needsDisplay = true
        follow()

        guard !isActive else { return }
        isActive = true
        window.orderFrontRegardless()
        let cid = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        CGDisplayHideCursor(CGMainDisplayID())
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.follow() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func hide() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        CGDisplayShowCursor(CGMainDisplayID())
    }

    /// Keeps the arrow's tip on the mouse position.
    private func follow() {
        guard let window, let view else { return }
        let mouse = NSEvent.mouseLocation
        let pad = ArrowView.padding(for: view.arrowHeight)
        window.setFrameOrigin(NSPoint(x: mouse.x - pad, y: mouse.y - window.frame.height + pad))
    }

    private func makeWindow() {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let view = ArrowView()
        window.contentView = view
        self.window = window
        self.view = view
    }
}

/// The classic macOS arrow, tip at the top-left inside `padding`.
private final class ArrowView: NSView {
    var arrowHeight: CGFloat = 16
    var fill: NSColor = .black
    var outline: NSColor = .white

    static func padding(for height: CGFloat) -> CGFloat { height * 0.06 }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let unit: [(CGFloat, CGFloat)] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
        let scale = arrowHeight / 0.93
        let pad = Self.padding(for: arrowHeight)
        let path = NSBezierPath()
        for (i, p) in unit.enumerated() {
            let point = NSPoint(x: pad + p.0 * scale, y: pad + p.1 * scale)
            i == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        path.lineJoinStyle = .round
        outline.setStroke()
        path.lineWidth = arrowHeight * 0.075
        path.stroke()
        fill.setFill()
        path.fill()
    }
}
