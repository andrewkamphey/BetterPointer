import AppKit

/// Puts a BetterPointer button in the Touch Bar's Control Strip. Tapping it opens
/// a row of the presets the user added to the Touch Bar.
///
/// A menu bar app is never frontmost, so the normal NSTouchBar route never shows.
/// This uses the private "system modal" Touch Bar calls (as Pock / MTMR do).
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private static let trayID = NSTouchBarItem.Identifier("com.betterpointer.BetterPointer.tray")

    private let onSelect: (Preset) -> Void
    private var presets: [Preset] = []
    private var activeID: UUID?
    /// Bumped on every update so the bar re-creates items with fresh names/colors.
    private var generation = 0
    private var trayInstalled = false
    private lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        return bar
    }()

    private static let setControlStripPresence: (@convention(c) (CFString, Bool) -> Void)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW),
              let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (CFString, Bool) -> Void).self)
    }()

    init(onSelect: @escaping (Preset) -> Void) {
        self.onSelect = onSelect
    }

    /// Shows `presets` in the Touch Bar, or removes the Control Strip button when empty.
    func update(presets: [Preset], activeID: UUID?) {
        self.presets = presets
        self.activeID = activeID
        generation += 1
        touchBar.defaultItemIdentifiers = presets.indices.map { identifier(for: $0) }

        if presets.isEmpty {
            Self.setControlStripPresence?(Self.trayID.rawValue as CFString, false)
            _ = (NSTouchBar.self as AnyObject).perform(NSSelectorFromString("dismissSystemModalTouchBar:"), with: touchBar)
            return
        }
        if !trayInstalled {
            let tray = NSCustomTouchBarItem(identifier: Self.trayID)
            tray.view = NSButton(image: NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "BetterPointer")!,
                                 target: self, action: #selector(present))
            _ = (NSTouchBarItem.self as AnyObject).perform(NSSelectorFromString("addSystemTrayItem:"), with: tray)
            trayInstalled = true
        }
        Self.setControlStripPresence?(Self.trayID.rawValue as CFString, true)
    }

    @objc private func present() {
        _ = (NSTouchBar.self as AnyObject).perform(NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:"),
                                                   with: touchBar, with: Self.trayID.rawValue)
    }

    private func identifier(for index: Int) -> NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("com.betterpointer.BetterPointer.preset.\(generation).\(index)")
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let index = Int(identifier.rawValue.split(separator: ".").last ?? ""), presets.indices.contains(index) else { return nil }
        let preset = presets[index]
        let title = preset.id == activeID ? "✓ \(preset.name)" : preset.name
        let button = NSButton(title: title, target: self, action: #selector(tapped(_:)))
        button.tag = index
        button.bezelColor = preset.fill.nsColor
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: preset.outline.nsColor,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
        ])
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = button
        return item
    }

    @objc private func tapped(_ sender: NSButton) {
        guard presets.indices.contains(sender.tag) else { return }
        onSelect(presets[sender.tag])
    }
}
