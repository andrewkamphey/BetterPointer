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
        UserDefaults.standard.set(true, forKey: "showAppRules") // show the rules in screenshots
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Sample presets and rules so the screenshot shows what the app does.
        let recording = Preset(name: "Recording", size: 4, fill: RGBA(red: 0, green: 0.45, blue: 1), outline: .white)
        let presenting = Preset(name: "Presenting", size: 6, fill: .red, outline: .white)
        let huge = Preset(name: "Huge Green", size: 12, fill: RGBA(red: 0.2, green: 0.8, blue: 0.3), outline: .black)
        let rules = [
            AppRule(bundleID: "com.obsproject.obs-studio", appName: "OBS", presetID: recording.id),
            AppRule(bundleID: "com.loom.desktop", appName: "Loom", presetID: recording.id),
            AppRule(bundleID: "com.apple.FaceTime", appName: "FaceTime", presetID: presenting.id),
        ]
        let store = PointerStore(snapshotOf: recording, presets: [recording, presenting, huge], rules: rules)
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
