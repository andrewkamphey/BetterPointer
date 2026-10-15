import AppKit
import SwiftUI

/// An sRGB color that can be stored in UserDefaults.
struct RGBA: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(nsColor: NSColor) {
        guard let c = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: c.alphaComponent)
    }

    init?(cgColor: CGColor) {
        guard let ns = NSColor(cgColor: cgColor) else { return nil }
        self.init(nsColor: ns)
    }

    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
    var cgColor: CGColor { nsColor.cgColor }
    var color: Color { Color(nsColor) }

    /// True for colors where white text or marks read better than black.
    var isDark: Bool { 0.299 * red + 0.587 * green + 0.114 * blue < 0.55 }

    func isClose(to other: RGBA) -> Bool {
        abs(red - other.red) < 0.01 && abs(green - other.green) < 0.01
            && abs(blue - other.blue) < 0.01 && abs(alpha - other.alpha) < 0.01
    }

    static let black = RGBA(red: 0, green: 0, blue: 0)
    static let white = RGBA(red: 1, green: 1, blue: 1)
    static let yellow = RGBA(red: 1, green: 0.9, blue: 0)
    static let red = RGBA(red: 1, green: 0.15, blue: 0.1)
}

/// Which app's rule applies when several rule apps are open.
enum RuleTrigger: String, CaseIterable, Identifiable {
    /// The app you're using; apps without a rule keep the last ruled app's preset.
    case activeApp
    /// The most recently launched rule app.
    case lastOpened

    var id: String { rawValue }
    var label: String { self == .activeApp ? "Active app" : "Last opened" }
}

/// "While this app is open, use this preset."
struct AppRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var bundleID: String
    var appName: String
    var presetID: UUID
}

struct Preset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var size: Double
    var fill: RGBA
    var outline: RGBA
    var isBuiltIn = false

    func matches(size: Double, fill: RGBA, outline: RGBA) -> Bool {
        abs(self.size - size) < 0.05 && self.fill.isClose(to: fill) && self.outline.isClose(to: outline)
    }

    static let builtIns: [Preset] = [
        builtIn(1, "Default", size: 1, fill: .black, outline: .white),
    ]

    /// Built-ins get fixed IDs so they stay stable across launches.
    private static func builtIn(_ n: Int, _ name: String, size: Double, fill: RGBA, outline: RGBA) -> Preset {
        Preset(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!,
               name: name, size: size, fill: fill, outline: outline, isBuiltIn: true)
    }
}
