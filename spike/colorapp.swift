import Foundation
import CoreGraphics

// Applies spike colors via the private UniversalAccess setters and logs the result.
let ua = dlopen("/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/UniversalAccess", RTLD_NOW)
typealias SetFn = @convention(c) (CGColor) -> Void
let setFill = unsafeBitCast(dlsym(ua, "_AXInterfaceSetCursorColorFill"), to: SetFn.self)
let setOut = unsafeBitCast(dlsym(ua, "_AXInterfaceSetCursorColorOutline"), to: SetFn.self)

setFill(CGColor(srgbRed: 0, green: 0.4, blue: 1, alpha: 1))
setOut(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
Thread.sleep(forTimeInterval: 1)

let plist = NSDictionary(contentsOfFile: NSHomeDirectory() + "/Library/Preferences/com.apple.universalaccess.plist")
let out = "fill=\(plist?["cursorFill"] ?? "nil")\noutline=\(plist?["cursorOutline"] ?? "nil")\n"
try? out.write(toFile: CommandLine.arguments[0] + ".log", atomically: true, encoding: .utf8)
