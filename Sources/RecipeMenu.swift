import AppKit

/// The Recipes dropdown in the menu, and wheresmymouse://recipe links from the website.
/// Either way, a recipe becomes one of your own presets and is applied right away.
enum RecipeMenu {
    static let galleryURL = URL(string: "https://wheresmymouse.com/recipes")!

    /// Pops up the recipes, one submenu per category, at the mouse.
    static func show(store: PointerStore) {
        let menu = NSMenu()
        let header = NSMenuItem(title: "Add a recipe as a preset", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for category in Recipe.categories {
            let submenu = NSMenu()
            for recipe in Recipe.all where recipe.category == category {
                guard let fill = RGBA(hex: recipe.fill), let outline = RGBA(hex: recipe.outline) else { continue }
                let item = ActionItem(title: "\(recipe.name)  ·  \(sizeText(recipe.size))") {
                    store.addRecipe(name: recipe.name, size: recipe.size, fill: fill, outline: outline)
                }
                item.image = pointerImage(fill: fill, outline: outline, height: 16)
                submenu.addItem(item)
            }
            let item = NSMenuItem(title: category, action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem(title: "Browse recipes on wheresmymouse.com…") { NSWorkspace.shared.open(galleryURL) })
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// Handles wheresmymouse://recipe?name=Klein%20Blue&size=6&fill=002FA7&outline=FFFFFF
    /// Any page can open a link like this, so it always asks before adding.
    static func handle(_ url: URL, store: PointerStore, then: () -> Void) {
        guard url.scheme == "wheresmymouse", url.host == "recipe",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return }
        func value(_ key: String) -> String? { items.first { $0.name == key }?.value }
        guard let size = value("size").flatMap(Double.init), (1...CursorController.extendedMaxSize).contains(size),
              let fill = value("fill").flatMap(RGBA.init(hex:)),
              let outline = value("outline").flatMap(RGBA.init(hex:)) else { return }
        let name = String((value("name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))

        let alert = NSAlert()
        alert.messageText = "Add “\(name.isEmpty ? "Recipe" : name)” to your presets?"
        alert.informativeText = "\(sizeText(size)) · fill #\(fill.hex) · outline #\(outline.hex)\n\nFrom a Cursor Recipe link."
        alert.icon = pointerImage(fill: fill, outline: outline, height: 56)
        alert.addButton(withTitle: "Add and Use")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.addRecipe(name: name.isEmpty ? "Recipe" : name, size: size, fill: fill, outline: outline)
        then()
    }

    static func sizeText(_ size: Double) -> String {
        size == size.rounded() ? "\(Int(size))×" : String(format: "%.1f×", size)
    }

    /// The arrow in a recipe's fill and outline.
    static func pointerImage(fill: RGBA, outline: RGBA, height: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: height * 0.75, height: height + 2), flipped: true) { _ in
            let path = NSBezierPath.pointerArrow(height: height - 2, origin: NSPoint(x: 1.5, y: 1.5))
            path.lineWidth = max(1.2, height / 14)
            outline.nsColor.setStroke()
            fill.nsColor.setFill()
            path.fill()
            path.stroke()
            return true
        }
    }
}

/// A menu item that runs a closure.
private final class ActionItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}

extension NSBezierPath {
    /// The classic arrow pointer, tip at `origin`, in flipped coordinates.
    static func pointerArrow(height: CGFloat, origin: NSPoint) -> NSBezierPath {
        let unit: [(CGFloat, CGFloat)] = [(0, 0), (0, 0.80), (0.19, 0.62), (0.32, 0.93), (0.45, 0.87), (0.32, 0.57), (0.57, 0.57)]
        let scale = height / 0.93
        let path = NSBezierPath()
        for (i, p) in unit.enumerated() {
            let point = NSPoint(x: origin.x + p.0 * scale, y: origin.y + p.1 * scale)
            i == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        path.lineJoinStyle = .round
        return path
    }
}
