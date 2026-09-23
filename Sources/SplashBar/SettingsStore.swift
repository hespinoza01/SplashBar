import Foundation
import Combine

/// Persisted launch flags for `splash serve`. Numeric value + unit are stored separately so the
/// UI can validate each independently; `maxMemoryFlag`/`maxContextFlag` compose them back into
/// the string Splash's CLI expects (e.g. "28G", "64K").
final class SettingsStore: ObservableObject {
    @Published var maxMemoryValue: String {
        didSet { UserDefaults.standard.set(maxMemoryValue, forKey: "maxMemoryValue") }
    }
    @Published var maxMemoryUnit: SizeUnit {
        didSet { UserDefaults.standard.set(maxMemoryUnit.rawValue, forKey: "maxMemoryUnit") }
    }
    @Published var maxContextValue: String {
        didSet { UserDefaults.standard.set(maxContextValue, forKey: "maxContextValue") }
    }
    @Published var maxContextUnit: SizeUnit {
        didSet { UserDefaults.standard.set(maxContextUnit.rawValue, forKey: "maxContextUnit") }
    }
    @Published var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            LoginItemManager.setEnabled(launchAtLogin)
        }
    }

    /// Defaults tuned for a machine with headroom similar to a 48GB M4 Max already running a
    /// normal dev workload (IDEs, browser, opencode): leaves room for everything else instead
    /// of letting Splash claim the whole unified memory pool or the full 256K context by default.
    static let defaultMaxMemoryValue = "28"
    static let defaultMaxMemoryUnit = SizeUnit.g
    static let defaultMaxContextValue = "64"
    static let defaultMaxContextUnit = SizeUnit.k

    init() {
        let defaults = UserDefaults.standard
        maxMemoryValue = defaults.string(forKey: "maxMemoryValue") ?? Self.defaultMaxMemoryValue
        maxMemoryUnit = SizeUnit(rawValue: defaults.string(forKey: "maxMemoryUnit") ?? "") ?? Self.defaultMaxMemoryUnit
        maxContextValue = defaults.string(forKey: "maxContextValue") ?? Self.defaultMaxContextValue
        maxContextUnit = SizeUnit(rawValue: defaults.string(forKey: "maxContextUnit") ?? "") ?? Self.defaultMaxContextUnit
        port = defaults.string(forKey: "port") ?? "8000"
        // Source of truth is the system's registration, not our own cached flag: the user could
        // have removed it from System Settings > General > Login Items directly.
        launchAtLogin = LoginItemManager.isEnabled
    }

    var maxMemoryFlag: String? {
        guard !maxMemoryValue.isEmpty else { return nil }
        return "\(maxMemoryValue)\(maxMemoryUnit.rawValue)"
    }

    var maxContextFlag: String? {
        guard !maxContextValue.isEmpty else { return nil }
        return "\(maxContextValue)\(maxContextUnit.rawValue)"
    }

    var serveArgs: (extra: [String], port: Int) {
        var args: [String] = []
        if let memFlag = maxMemoryFlag { args += ["--max-memory", memFlag] }
        if let ctxFlag = maxContextFlag { args += ["--max-context", ctxFlag] }
        let resolvedPort = Int(port) ?? 8000
        args += ["--port", String(resolvedPort)]
        return (args, resolvedPort)
    }
}

/// Keeps a bound string field digits-only as the user types, without fighting SwiftUI's
/// TextField cursor by mutating text mid-keystroke in ways that jump the caret.
func filterDigits(_ input: String) -> String {
    input.filter(\.isNumber)
}
