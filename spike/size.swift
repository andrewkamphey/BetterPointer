import Foundation
import CoreGraphics

@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetCursorScale") func CGSGetCursorScale(_ cid: Int32, _ scale: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("CGSSetCursorScale") func CGSSetCursorScale(_ cid: Int32, _ scale: Float) -> Int32

let cid = CGSMainConnectionID()
var cur: Float = 0
print("get err=\(CGSGetCursorScale(cid, &cur)) scale=\(cur)")
if CommandLine.arguments.count > 1, let s = Float(CommandLine.arguments[1]) {
    print("set \(s) err=\(CGSSetCursorScale(cid, s))")
    var after: Float = 0
    _ = CGSGetCursorScale(cid, &after)
    print("after=\(after)")
}
