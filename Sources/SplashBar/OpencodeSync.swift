import Foundation

/// Keeps opencode's declared context limit for the "splash" provider in sync with whatever
/// context the currently running Splash server actually enforces.
///
/// opencode has no way to ask an openai-compatible provider "what's your real context window" —
/// its config declares a static number. That number silently drifts from reality the moment you
/// change --max-context in SplashBar (see `RecommendedDefaults`/`SettingsStore`), and the failure
/// mode is opaque: opencode happily builds a prompt up to its stale declared limit, Splash
/// rejects it outright with "prompt exceeds the context window".
///
/// This patches only the numeric `"context": <n>` values inside the `"splash": { ... }` provider
/// block via brace-counted text surgery — never a full JSON parse + re-serialize, which would
/// reformat and reorder the rest of a large, hand-maintained config file the user didn't ask to
/// touch.
enum OpencodeSync {
    static var configPath: String {
        UserDefaults.standard.string(forKey: "opencodeConfigPath")
            ?? (NSHomeDirectory() + "/.config/opencode/opencode.json")
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "opencodeSyncEnabled") as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "opencodeSyncEnabled")
    }

    static func setConfigPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "opencodeConfigPath")
    }

    /// Queries the running server's real context ceiling and patches opencode.json to match.
    /// Safe to call even if opencode isn't installed or the config path doesn't exist — it just
    /// silently does nothing in that case rather than erroring.
    static func syncFromRunningServer(port: String) async {
        guard isEnabled else { return }
        guard let url = URL(string: "http://127.0.0.1:\(port)/status") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contextTokens = json["maximum_context_tokens"] as? Int else {
            return
        }
        _ = syncContext(contextTokens)
    }

    /// Rewrites every `"context": <number>` inside the `"splash": { ... }` provider block.
    /// Returns true if the file was found, the block was found, and at least one value changed.
    @discardableResult
    static func syncContext(_ contextTokens: Int) -> Bool {
        let path = configPath
        guard var text = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        guard let providerRange = findBraceBlock(in: text, afterKey: "\"splash\"") else { return false }

        let block = String(text[providerRange])
        let patchedBlock = block.replacingOccurrences(
            of: #""context":\s*\d+"#,
            with: "\"context\": \(contextTokens)",
            options: .regularExpression
        )
        guard patchedBlock != block else { return false }

        text.replaceSubrange(providerRange, with: patchedBlock)
        return (try? text.write(toFile: path, atomically: true, encoding: .utf8)) != nil
    }

    /// Finds the `{ ... }` object that follows `"<key>":`, counting braces so nested objects
    /// inside it (e.g. each model's own `limit: {...}`) don't confuse where the block ends.
    private static func findBraceBlock(in text: String, afterKey key: String) -> Range<String.Index>? {
        guard let keyRange = text.range(of: key) else { return nil }
        guard let colonRange = text.range(of: ":", range: keyRange.upperBound..<text.endIndex) else { return nil }
        guard let openBrace = text.range(of: "{", range: colonRange.upperBound..<text.endIndex) else { return nil }

        var depth = 0
        var index = openBrace.lowerBound
        while index < text.endIndex {
            let ch = text[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return openBrace.lowerBound..<text.index(after: index)
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
