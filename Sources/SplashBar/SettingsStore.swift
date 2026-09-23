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
    /// When true, `--max-context` is omitted entirely and Splash falls back to its own default
    /// (the model's real maximum), instead of the value/unit fields below.
    @Published var contextIsAuto: Bool {
        didSet { UserDefaults.standard.set(contextIsAuto, forKey: "contextIsAuto") }
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
    @Published var opencodeSyncEnabled: Bool {
        didSet { OpencodeSync.setEnabled(opencodeSyncEnabled) }
    }
    @Published var opencodeConfigPath: String {
        didSet { OpencodeSync.setConfigPath(opencodeConfigPath) }
    }

    /// Computed once per launch from this machine's real RAM — not a hardcoded number — so the
    /// same app suggests different values on a 36GB minimum-spec Mac vs. a 64GB/128GB one.
    let recommended = RecommendedDefaults.compute()

    init() {
        let defaults = UserDefaults.standard
        let recommended = RecommendedDefaults.compute()
        maxMemoryValue = defaults.string(forKey: "maxMemoryValue") ?? recommended.memoryValue
        maxMemoryUnit = SizeUnit(rawValue: defaults.string(forKey: "maxMemoryUnit") ?? "") ?? recommended.memoryUnit
        maxContextValue = defaults.string(forKey: "maxContextValue") ?? recommended.contextValue
        maxContextUnit = SizeUnit(rawValue: defaults.string(forKey: "maxContextUnit") ?? "") ?? recommended.contextUnit
        contextIsAuto = defaults.bool(forKey: "contextIsAuto")
        port = defaults.string(forKey: "port") ?? "8000"
        // Source of truth is the system's registration, not our own cached flag: the user could
        // have removed it from System Settings > General > Login Items directly.
        launchAtLogin = LoginItemManager.isEnabled
        opencodeSyncEnabled = OpencodeSync.isEnabled
        opencodeConfigPath = OpencodeSync.configPath
    }

    /// Resets memory/context back to what `RecommendedDefaults` computes for this machine.
    /// Port and login-item are left untouched — those aren't resource-dependent.
    func resetToRecommendedDefaults() {
        maxMemoryValue = recommended.memoryValue
        maxMemoryUnit = recommended.memoryUnit
        maxContextValue = recommended.contextValue
        maxContextUnit = recommended.contextUnit
        contextIsAuto = false
    }

    var maxMemoryFlag: String? {
        guard !maxMemoryValue.isEmpty else { return nil }
        return "\(maxMemoryValue)\(maxMemoryUnit.rawValue)"
    }

    var maxContextFlag: String? {
        guard !contextIsAuto, !maxContextValue.isEmpty else { return nil }
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
