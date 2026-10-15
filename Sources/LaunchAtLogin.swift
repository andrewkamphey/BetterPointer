import Foundation
import ServiceManagement

/// Launch at login: SMAppService on macOS 13+, a LaunchAgent in ~/Library/LaunchAgents before that.
enum LaunchAtLogin {
    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.wheresmymouse.WheresMyMouse.plist")
    }

    static var isEnabled: Bool {
        if #available(macOS 13, *) { return SMAppService.mainApp.status == .enabled }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func set(_ on: Bool) {
        if #available(macOS 13, *) {
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("WheresMyMouse: launch at login change failed: \(error)")
            }
            return
        }
        if on {
            let agent: [String: Any] = [
                "Label": "com.wheresmymouse.WheresMyMouse",
                "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
                "RunAtLoad": true,
            ]
            try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            (agent as NSDictionary).write(to: agentURL, atomically: true)
        } else {
            try? FileManager.default.removeItem(at: agentURL)
        }
    }
}
