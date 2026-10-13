import Foundation
import CoreGraphics
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSSetCursorScale") func CGSSetCursorScale(_ cid: Int32, _ scale: Float) -> Int32
typealias SizeFn = @convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32
let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
let CGSGetGlobalCursorDataSize = unsafeBitCast(dlsym(sky, "SLSGetGlobalCursorDataSize")!, to: SizeFn.self)
let cid = CGSMainConnectionID()
for s: Float in [1, 2, 4, 6, 8, 12, 16] {
    _ = CGSSetCursorScale(cid, s); usleep(400_000)
    var n: Int32 = 0; let e = CGSGetGlobalCursorDataSize(cid, &n)
    print("scale \(s): err=\(e) bytes=\(n) ~\(Int(sqrt(Double(n)/4)))px square")
}
_ = CGSSetCursorScale(cid, Float(CommandLine.arguments[1])!)
