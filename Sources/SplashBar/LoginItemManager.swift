import Foundation
import ServiceManagement

/// Registers SplashBar as a login item using SMAppService (macOS 13+), the modern replacement
/// for the deprecated SMLoginItemSetEnabled/LSSharedFileList APIs. Works for a plain .app bundle
/// launched directly (no separate helper target needed) via `.mainApp`.
enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SplashBar: no se pudo cambiar login item: \(error.localizedDescription)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
