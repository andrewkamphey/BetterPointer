import Foundation
let d = "com.apple.universalaccess" as CFString
CFPreferencesSetValue("cursorIsCustomized" as CFString, true as CFBoolean, d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
print("sync=\(CFPreferencesSynchronize(d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost))")
