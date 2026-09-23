import Foundation

struct ModelEntry: Identifiable, Hashable {
    var id: String { repoId }
    let repoId: String
    var isInstalled: Bool

    var shortName: String {
        // "incoai/Qwen3.8-27B-Splash" -> "Qwen3.8-27B"
        repoId.split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "-Splash", with: "") ?? repoId
    }
}

enum ModelCatalog {
    /// Official models Splash ships support for, read from its own bundled catalog file
    /// so a `brew upgrade splash` that adds a model shows up here with no code change.
    static func officialModels() -> [String] {
        guard let text = try? String(contentsOf: SplashPaths.catalogFile, encoding: .utf8) else {
            // Fallback if the file ever moves: the two models known at the time this was written.
            return ["incoai/Qwen3.8-27B-Splash", "incoai/Qwen3.6-35B-A3B-Splash"]
        }
        return text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func installedRepoIds() -> Set<String> {
        let root = SplashPaths.modelsRoot.appendingPathComponent("incoai")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
            return []
        }
        return Set(entries.map { "incoai/\($0)" })
    }

    static func all() -> [ModelEntry] {
        let installed = installedRepoIds()
        return officialModels().map { ModelEntry(repoId: $0, isInstalled: installed.contains($0)) }
    }
}
