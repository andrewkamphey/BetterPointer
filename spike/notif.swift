import Foundation
let ua = dlopen("/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/UniversalAccess", RTLD_NOW)
for n in ["kAXInterfaceCursorStatusDidChangeNotification", "UADomainPointerControlSettingsDidChangeNotification"] {
    if let p = dlsym(ua, n) { print(n, "=", p.assumingMemoryBound(to: CFString?.self).pointee as Any) } else { print(n, "missing") }
}
for f in ["_AXInterfaceSetCursorIsOverridden", "_AXInterfaceCursorIsOverridden"] { print(f, dlsym(ua, f) != nil) }
typealias B = @convention(c) () -> Bool
if let p = dlsym(ua, "_AXInterfaceCursorIsOverridden") { print("isOverridden =", unsafeBitCast(p, to: B.self)()) }
