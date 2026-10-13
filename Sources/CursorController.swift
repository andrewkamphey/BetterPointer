import AppKit
import CoreGraphics

// Size: private CoreGraphics (SkyLight) calls. Applies live, no permissions needed.
@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetCursorScale") private func CGSGetCursorScale(_ cid: Int32, _ scale: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("CGSSetCursorScale") private func CGSSetCursorScale(_ cid: Int32, _ scale: Float) -> Int32

/// Reads and writes the system pointer's size and colors.
///
/// Colors go through the same private UniversalAccess calls System Settings uses.
/// They write `cursorFill` / `cursorOutline` in com.apple.universalaccess, which
/// macOS only allows for processes with Full Disk Access.
enum CursorController {
    static let sizeRange: ClosedRange<Double> = 1...10
    /// System Settings' own maximum. Larger sizes render fine, but only this
    /// much is written to the system preference; the app re-applies the rest.
    static let systemMaxSize: Double = 4

    private static let domain = "com.apple.universalaccess" as CFString
    private static let sizeKey = "mouseDriverCursorSize" as CFString

    private typealias CopyColorFn = @convention(c) () -> Unmanaged<CGColor>?
    private typealias SetColorFn = @convention(c) (CGColor) -> Void

    private static let universalAccess = dlopen(
        "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/UniversalAccess", RTLD_NOW)

    private static func lookup<T>(_ name: String, as _: T.Type) -> T? {
        guard let universalAccess, let symbol = dlsym(universalAccess, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    private static let copyFill = lookup("_AXInterfaceCopyCursorColorFill", as: CopyColorFn.self)
    private static let copyOutline = lookup("_AXInterfaceCopyCursorColorOutline", as: CopyColorFn.self)
    private static let setFill = lookup("_AXInterfaceSetCursorColorFill", as: SetColorFn.self)
    private static let setOutline = lookup("_AXInterfaceSetCursorColorOutline", as: SetColorFn.self)

    // MARK: Size

    static var size: Double {
        var scale: Float = 1
        _ = CGSGetCursorScale(CGSMainConnectionID(), &scale)
        return Double(scale)
    }

    /// Applies the size live. `persist` also saves it (capped at 4×) so it survives logout.
    static func setSize(_ size: Double, persist: Bool) {
        let clamped = min(max(size, sizeRange.lowerBound), sizeRange.upperBound)
        _ = CGSSetCursorScale(CGSMainConnectionID(), Float(clamped))
        if persist {
            CFPreferencesSetValue(sizeKey, NSNumber(value: min(clamped, systemMaxSize)), domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
    }

    // MARK: Colors

    static var fill: RGBA? { (copyFill?()?.takeRetainedValue()).flatMap(RGBA.init(cgColor:)) }
    static var outline: RGBA? { (copyOutline?()?.takeRetainedValue()).flatMap(RGBA.init(cgColor:)) }

    private typealias VoidFn = @convention(c) () -> Void
    private static let accessibilityFoundation = dlopen(
        "/System/Library/PrivateFrameworks/AccessibilitySupport.framework/Versions/A/Frameworks/AccessibilityFoundation.framework/Versions/A/AccessibilityFoundation", RTLD_NOW)
    private static let registerCursors: VoidFn? = accessibilityFoundation
        .flatMap { dlsym($0, "AXFCursorRegisterAll") }.map { unsafeBitCast($0, to: VoidFn.self) }
    private static let unregisterCursors: VoidFn? = accessibilityFoundation
        .flatMap { dlsym($0, "AXFCursorUnregisterAll") }.map { unsafeBitCast($0, to: VoidFn.self) }

    /// The private setters only stage the values in preferences. Like System
    /// Settings, we then flush them and re-register the system pointer images,
    /// which redraws them in the new colors right away.
    static func setColors(fill: RGBA, outline: RGBA) {
        setOutline?(outline.cgColor)
        setFill?(fill.cgColor)
        CFPreferencesAppSynchronize(domain)
        unregisterCursors?()
        registerCursors?()
    }

    // MARK: Permissions

    /// Full Disk Access probe: the TCC database is only readable with it.
    static var hasFullDiskAccess: Bool {
        let path = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        try? handle.close()
        return true
    }

    static func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
}
