import Foundation
import Combine

enum SplashState: Equatable {
    case idle
    case downloading(model: String, percent: Int, file: String)
    case loading(model: String)
    case ready(model: String, context: String)
    case stopping
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Detenido"
        case .downloading(let model, let pct, _): return "Bajando \(model.split(separator: "/").last ?? "") \(pct)%"
        case .loading(let model): return "Cargando \(model.split(separator: "/").last ?? "")…"
        case .ready(let model, _): return "Activo: \(model.split(separator: "/").last ?? "")"
        case .stopping: return "Deteniendo…"
        case .failed(let msg): return "Error: \(msg)"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .idle: return "circle"
        case .downloading: return "arrow.down.circle"
        case .loading: return "hourglass.circle"
        case .ready: return "checkmark.circle.fill"
        case .stopping: return "circle.dotted"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class SplashController: ObservableObject {
    @Published var state: SplashState = .idle
    @Published var logTail: [String] = []
    @Published var downloadOnlyProgress: (model: String, percent: Int)? = nil
    @Published var lastMetrics: String = ""
    /// Flags the currently running server was actually launched with, for display in the UI.
    /// Nil fields mean "unknown" (e.g. a server detected at launch that this app didn't start).
    @Published var activeConfig: (port: String, maxMemory: String?, maxContext: String?)?

    private var serveProcess: Process?
    private var downloadProcess: Process?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        Task { await detectRunningServer() }
    }

    // MARK: - Detect a server already running (e.g. started before this app launched)

    func detectRunningServer() async {
        let port = Int(settings.port) ?? 8000
        guard let url = URL(string: "http://127.0.0.1:\(port)/v1/models") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]],
              let first = items.first,
              let modelId = first["id"] as? String else {
            return
        }
        state = .ready(model: modelId, context: "?")
        activeConfig = (port: settings.port, maxMemory: nil, maxContext: nil)
    }

    // MARK: - Load (serve) a model

    func load(_ repoId: String) {
        guard serveProcess == nil else { return }
        appendLog("--- iniciando splash serve --model \(repoId) ---")
        state = .loading(model: repoId)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: SplashPaths.binary)
        let (extraArgs, resolvedPort) = settings.serveArgs
        process.arguments = ["serve", "--model", repoId] + extraArgs
        activeConfig = (
            port: String(resolvedPort),
            maxMemory: settings.maxMemoryFlag,
            maxContext: settings.maxContextFlag
        )

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.consume(chunk: chunk, model: repoId) }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.serveProcess = nil
                self?.activeConfig = nil
                pipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus != 0, case .ready = self?.state ?? .idle {
                    // Was ready and died unexpectedly.
                    self?.state = .failed("el server se cerró (código \(proc.terminationStatus))")
                } else if case .failed = self?.state ?? .idle {
                    // keep failed state as-is
                } else {
                    self?.state = .idle
                }
            }
        }

        do {
            try process.run()
            serveProcess = process
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func consume(chunk: String, model: String) {
        for rawLine in chunk.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            guard !line.isEmpty else { continue }
            appendLog(line)

            if let range = line.range(of: #"Fetching \d+ files:\s+(\d+)%"#, options: .regularExpression) {
                let match = String(line[range])
                if let pct = match.split(separator: " ").last(where: { $0.hasSuffix("%") })?.dropLast(),
                   let pctInt = Int(pct) {
                    state = .downloading(model: model, percent: pctInt, file: "")
                }
            } else if line.contains("Loading ·") {
                state = .loading(model: model)
            } else if line.contains("Ready ·") {
                let context = extractField(line, marker: "context ") ?? "?"
                state = .ready(model: model, context: context)
            } else if line.contains("Done ·") {
                lastMetrics = line
            } else if line.lowercased().contains("traceback") || line.lowercased().contains("error:") {
                state = .failed(line)
            }
        }
    }

    private func extractField(_ line: String, marker: String) -> String? {
        guard let markerRange = line.range(of: marker) else { return nil }
        let rest = line[markerRange.upperBound...]
        return rest.split(separator: "·").first?.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Stop

    func stop() {
        state = .stopping
        if let process = serveProcess, process.isRunning {
            process.terminate()
        } else {
            // Server running from a previous, untracked launch: kill by port match.
            let port = settings.port
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-f", "server.py.*--port \(port)"]
            try? task.run()
            task.waitUntilExit()
        }
        activeConfig = nil
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { self.state = .idle }
        }
    }

    // MARK: - Download without loading into the server

    func download(_ repoId: String, onDone: @escaping @Sendable (Bool) -> Void) {
        guard downloadProcess == nil else { return }
        downloadOnlyProgress = (repoId, 0)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "\(SplashPaths.brewPrefix)/opt/splash/libexec/python/bin/python3")
        process.arguments = [
            "\(SplashPaths.brewPrefix)/opt/splash/libexec/install/models.py",
            "--models", SplashPaths.modelsRoot.path,
            "--model", repoId,
            "prepare",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLog(chunk)
                if let range = chunk.range(of: #"(\d+)%"#, options: .regularExpression) {
                    let pctStr = chunk[range].dropLast()
                    if let pct = Int(pctStr) {
                        self?.downloadOnlyProgress = (repoId, pct)
                    }
                }
            }
        }
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.downloadProcess = nil
                self?.downloadOnlyProgress = nil
                pipe.fileHandleForReading.readabilityHandler = nil
                onDone(proc.terminationStatus == 0)
            }
        }

        do {
            try process.run()
            downloadProcess = process
        } catch {
            downloadOnlyProgress = nil
            onDone(false)
        }
    }

    // MARK: - Delete a downloaded model from disk

    func delete(_ repoId: String) -> Bool {
        guard let repoRoot = SplashPaths.hfRepoRoot(for: repoId) else { return false }
        let symlink = SplashPaths.modelsRoot.appendingPathComponent(repoId)
        let fm = FileManager.default
        try? fm.removeItem(at: symlink)
        do {
            try fm.removeItem(at: repoRoot)
            return true
        } catch {
            appendLog("No se pudo borrar \(repoRoot.path): \(error.localizedDescription)")
            return false
        }
    }

    func dismissError() {
        if case .failed = state { state = .idle }
    }

    private func appendLog(_ line: String) {
        logTail.append(line)
        if logTail.count > 200 { logTail.removeFirst(logTail.count - 200) }
    }
}
