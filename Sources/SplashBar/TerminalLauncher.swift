import Foundation
import AppKit

enum TerminalLauncher {
    /// Runs a shell command in a new Terminal.app window.
    ///
    /// Deliberately avoids AppleScript's `tell application "Terminal" to do script` — that
    /// requires one-time Automation (TCC) permission for this app to control Terminal, which on
    /// an unsigned/ad-hoc-signed app can fail silently (Terminal activates, but the script never
    /// runs, no visible error) if the grant didn't stick or the prompt never surfaced.
    ///
    /// Writing a `.command` file and `open`-ing it sidesteps that entirely: `.command` is a
    /// LaunchServices file type Terminal.app already owns, so `open` launches it exactly like a
    /// double-click in Finder would, no Automation/Apple Events permission involved.
    static func run(_ command: String) {
        let script = "#!/bin/zsh\n\(command)\n"
        let dir = FileManager.default.temporaryDirectory
        let file = dir.appendingPathComponent("splashbar-\(UUID().uuidString).command")

        do {
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
            NSWorkspace.shared.open(file)
        } catch {
            NSLog("SplashBar: failed to launch terminal command: \(error.localizedDescription)")
        }
    }
}
