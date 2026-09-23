import Foundation

/// Resolves filesystem locations Splash uses, independent of Homebrew prefix (Intel vs Apple Silicon).
enum SplashPaths {
    static var brewPrefix: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/splash") {
            return "/opt/homebrew"
        }
        return "/usr/local"
    }

    static var binary: String { "\(brewPrefix)/bin/splash" }

    static var catalogFile: URL {
        URL(fileURLWithPath: "\(brewPrefix)/opt/splash/libexec/install/completions/official-models.txt")
    }

    static var modelsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Splash/models")
    }

    /// The real on-disk snapshot a model symlink points to, so deletion frees actual space
    /// instead of orphaning the Hugging Face cache blobs.
    static func resolvedSnapshotPath(for repoId: String) -> URL? {
        let link = modelsRoot.appendingPathComponent(repoId)
        guard let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else {
            return nil
        }
        if dest.hasPrefix("/") {
            return URL(fileURLWithPath: dest)
        }
        return link.deletingLastPathComponent().appendingPathComponent(dest).standardized
    }

    /// The Hugging Face repo root (models--incoai--Name) that owns the blobs; deleting this
    /// frees disk, unlike deleting just the Splash-side symlink.
    static func hfRepoRoot(for repoId: String) -> URL? {
        guard let snapshot = resolvedSnapshotPath(for: repoId) else { return nil }
        // snapshot looks like: .../hub/models--incoai--Name/snapshots/<hash>
        let snapshotsDir = snapshot.deletingLastPathComponent()
        guard snapshotsDir.lastPathComponent == "snapshots" else { return nil }
        return snapshotsDir.deletingLastPathComponent()
    }
}
