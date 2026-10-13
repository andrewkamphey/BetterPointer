import Foundation
// Search loaded images (from the shared cache) for a C string.
let targets = CommandLine.arguments.dropFirst().map { Array($0.utf8) }
for lib in ["/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices",
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/UniversalAccess"] { dlopen(lib, RTLD_NOW) }
for i in 0..<_dyld_image_count() {
    let name = String(cString: _dyld_get_image_name(i))
    guard name.contains("SkyLight") || name.contains("HIServices") || name.contains("UniversalAccess") else { continue }
    guard let h = _dyld_get_image_header(i) else { continue }
    var size: UInt = 0
    for seg in ["__TEXT"] {
        guard let p = getsegmentdata(UnsafeRawPointer(h).assumingMemoryBound(to: mach_header_64.self), seg, &size) else { continue }
        let buf = UnsafeBufferPointer(start: p, count: Int(size))
        for t in targets {
            var hits = 0
            var idx = 0
            while idx + t.count <= buf.count { if buf[idx] == t[0] && Array(buf[idx..<idx+t.count]) == t { hits += 1; idx += t.count } else { idx += 1 } }
            if hits > 0 { print("\(name): '\(String(decoding: t, as: UTF8.self))' x\(hits)") }
        }
    }
}
