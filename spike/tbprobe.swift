import AppKit
for s in ["presentSystemModalTouchBar:systemTrayItemIdentifier:", "presentSystemModalTouchBar:placement:systemTrayItemIdentifier:", "dismissSystemModalTouchBar:", "minimizeSystemModalTouchBar:"] {
    print("NSTouchBar +\(s): \((NSTouchBar.self as AnyObject).responds(to: NSSelectorFromString(s)))")
}
for s in ["addSystemTrayItem:", "removeSystemTrayItem:"] {
    print("NSTouchBarItem +\(s): \((NSTouchBarItem.self as AnyObject).responds(to: NSSelectorFromString(s)))")
}
let h = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
for f in ["DFRElementSetControlStripPresenceForIdentifier", "DFRSystemModalShowsCloseBoxWhenFrontMost"] { print("\(f): \(dlsym(h, f) != nil)") }
