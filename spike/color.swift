import Foundation
import CoreGraphics

let libs = ["/usr/lib/libAccessibility.dylib",
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Libraries/libUAPreferences.dylib",
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/UniversalAccess"]
func sym(_ n: String) -> UnsafeMutableRawPointer? {
    for l in libs { if let h = dlopen(l, RTLD_NOW), let s = dlsym(h, n) { print("\(n) in \(l)"); return s } }
    return nil
}
typealias CopyFn = @convention(c) () -> Unmanaged<CGColor>?
typealias SetFn = @convention(c) (CGColor) -> Void

guard let cf = sym("_AXInterfaceCopyCursorColorFill"), let co = sym("_AXInterfaceCopyCursorColorOutline"),
      let sf = sym("_AXInterfaceSetCursorColorFill"), let so = sym("_AXInterfaceSetCursorColorOutline") else { print("missing"); exit(1) }
let copyFill = unsafeBitCast(cf, to: CopyFn.self), copyOut = unsafeBitCast(co, to: CopyFn.self)
let setFill = unsafeBitCast(sf, to: SetFn.self), setOut = unsafeBitCast(so, to: SetFn.self)
print("fill=\(String(describing: copyFill()?.takeRetainedValue().components)) outline=\(String(describing: copyOut()?.takeRetainedValue().components))")
let a = CommandLine.arguments
if a.count == 7, let v = a[1...].compactMap({ Double($0) }) as [Double]?, v.count == 6 {
    setFill(CGColor(srgbRed: v[0], green: v[1], blue: v[2], alpha: 1))
    setOut(CGColor(srgbRed: v[3], green: v[4], blue: v[5], alpha: 1))
    print("after fill=\(String(describing: copyFill()?.takeRetainedValue().components)) outline=\(String(describing: copyOut()?.takeRetainedValue().components))")
}
