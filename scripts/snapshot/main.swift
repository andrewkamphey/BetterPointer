// Renders the real menu UI to a PNG for the README and share image.
// Built by scripts/snapshot-menu.sh; does not change the system pointer.
import AppKit
import SwiftUI

@main
enum SnapshotMenu {
    @MainActor
    static func main() {
        let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/menu.png"
        let dark = CommandLine.arguments.contains("--dark")
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let preset = Preset.builtIns.first { $0.name == "Default" }!
        let store = PointerStore(snapshotOf: preset)
        let root = MenuView()
            .environmentObject(store)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame.size = host.fittingSize

        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000)) // offscreen
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: rep)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
            print("Wrote \(output) (\(rep.pixelsWide)×\(rep.pixelsHigh))")
            exit(0)
        }
        app.run()
    }
}
