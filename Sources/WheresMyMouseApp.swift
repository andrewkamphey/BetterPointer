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

        // Keep the popover sized to its SwiftUI content as sections grow or shrink,
        // and badge the menu bar icon while colors are blocked.
        resize = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.fitPopover(); self?.updateIcon() }
        }
        store.onColorsBlocked = { [weak self] preset in self?.warnColorsBlocked(preset) }
        updateIcon()
    }

    /// wheresmymouse://recipe links from the website's Cursor Recipes.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let store = store else { return }
        for url in urls { RecipeMenu.handle(url, store: store) { [weak self] in self?.showPopover() } }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let sender = statusItem?.button, !popover.isShown else { return }
        store?.refresh()
        fitPopover()
        NSApp.activate(ignoringOtherApps: true) // so text fields take typing
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private var colorsBlocked: Bool { CursorController.colorsSupported && store?.hasFullDiskAccess == false }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let blocked = colorsBlocked
        button.image = blocked ? Self.blockedIcon : Self.menuBarIcon
        button.toolTip = blocked ? "Where's My Mouse? (colors need Full Disk Access)" : "Where's My Mouse?"
    }

    /// Shown once per launch when a preset (often an app rule) couldn't change colors.
    private func warnColorsBlocked(_ preset: Preset) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Pointer colors are blocked"
        alert.informativeText = "“\(preset.name)” changed the size, but its colors need Full Disk Access.\n\n"
            + "In Privacy & Security → Full Disk Access, add Where's My Mouse. If it's already listed, "
            + "remove it with − and add it again (needed once after updating), then reopen the app."
        alert.addButton(withTitle: "Open Full Disk Access")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { CursorController.openFullDiskAccessSettings() }
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
            let path = NSBezierPath.pointerArrow(height: height, origin: NSPoint(x: 1.5, y: 1))
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

    /// The menu bar icon with an orange warning dot.
    private static let blockedIcon: NSImage = {
        let base = menuBarIcon
        return NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            base.draw(in: NSRect(x: 0, y: 0, width: 12, height: 18))
            let dot = NSBezierPath(ovalIn: NSRect(x: 10, y: 1, width: 8, height: 8))
            NSColor.systemOrange.setFill()
            dot.fill()
            return true
        }
    }()
}
