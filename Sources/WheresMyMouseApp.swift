import AppKit
import Combine
import SwiftUI

/// Menu bar app entry point. Built on NSStatusItem + NSPopover (rather than SwiftUI's
/// MenuBarExtra, which needs macOS 13) so it runs on macOS 11 and later.
@main
enum WheresMyMouseMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var store: PointerStore?
    private var hosting: NSHostingController<AnyView>?
    private var resize: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = PointerStore()
        let hosting = NSHostingController(rootView: AnyView(MenuView().environmentObject(store)))
        popover.contentViewController = hosting
        popover.behavior = .transient
        self.store = store
        self.hosting = hosting

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon
        item.button?.toolTip = "Where's My Mouse?"
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item

        // Keep the popover sized to its SwiftUI content as sections grow or shrink.
        resize = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.fitPopover() }
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        store?.refresh()
        fitPopover()
        NSApp.activate(ignoringOtherApps: true) // so text fields take typing
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func fitPopover() {
        guard let view = hosting?.view else { return }
        let size = view.fittingSize
        if size.width > 0, size.height > 0, size != popover.contentSize { popover.contentSize = size }
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
