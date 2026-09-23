import Foundation
import AppKit

enum TerminalLauncher {
    /// Opens Terminal.app and runs the given shell command in a new window.
    /// Terminal.app is used regardless of the user's default terminal because it is always
    /// present and scriptable via AppleScript; other terminals (Warp, iTerm) vary in CLI support.
    static func run(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
