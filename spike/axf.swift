import Foundation
let h = dlopen("/System/Library/PrivateFrameworks/AccessibilitySupport.framework/Versions/A/Frameworks/AccessibilityFoundation.framework/Versions/A/AccessibilityFoundation", RTLD_NOW)
print("framework:", h != nil, "register:", h.flatMap { dlsym($0, "AXFCursorRegisterAll") } != nil, "unregister:", h.flatMap { dlsym($0, "AXFCursorUnregisterAll") } != nil)
