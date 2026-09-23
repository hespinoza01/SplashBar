import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: SplashController
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var modelsVM: ModelsViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(modelsVM.models) { model in
                        ModelRow(model: model)
                    }

                    Divider()

                    SettingsDisclosure(isExpanded: $showSettings)
                }
                .padding(14)
            }
            .frame(height: 340)

            Divider()

            footerBar
                .padding(14)
        }
        .frame(width: 360)
        .onAppear { modelsVM.refresh() }
    }

    private var statusHeader: some View {
        HStack {
            Image(systemName: controller.state.menuBarSymbol)
                .foregroundStyle(isFailed ? .red : .primary)
            Text(controller.state.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFailed ? .red : .primary)
                .lineLimit(2)
            Spacer()
            if case .downloading(_, let pct, _) = controller.state {
                Text("\(pct)%").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if isFailed {
                Button("Cerrar") { controller.dismissError() }
                    .controlSize(.mini)
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = controller.state { return true }
        return false
    }

    private var footerBar: some View {
        HStack {
            Button("WebUI") { openWebUI() }
                .disabled(!isServerReachable)

            Menu("Conectar") {
                Button("opencode") { connectAgent("opencode") }
                Button("Claude Code") { connectAgent("claude") }
                Button("Codex") { connectAgent("codex") }
                Button("Hermes") { connectAgent("hermes") }
            }
            .disabled(!isServerReachable)
            .fixedSize()

            Spacer()

            Button {
                openWindow(id: "about")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)

            Button("Salir") { NSApplication.shared.terminate(nil) }
        }
    }

    private var isServerReachable: Bool {
        if case .ready = controller.state { return true }
        return false
    }

    private func openWebUI() {
        guard let url = URL(string: "http://127.0.0.1:\(settings.port)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// `splash claude/opencode/codex/hermes` take no --port flag — they read SPLASH_PORT (or
    /// default to 8000) to find the running server. Exporting it inline is required whenever the
    /// server isn't on the default port, which is normal here since SplashBar's own default is
    /// port-configurable per the user's settings.
    private func connectAgent(_ name: String) {
        TerminalLauncher.run("SPLASH_PORT=\(settings.port) \(SplashPaths.binary) \(name)")
    }
}

private struct SettingsDisclosure: View {
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text("Configuración").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                SettingsPanel()
            }
        }
    }
}

private struct ModelRow: View {
    let model: ModelEntry
    @EnvironmentObject var controller: SplashController
    @EnvironmentObject var modelsVM: ModelsViewModel
    @State private var confirmingDelete = false

    var isThisModelActive: Bool {
        if case .ready(let m, _) = controller.state { return m == model.repoId }
        if case .loading(let m) = controller.state { return m == model.repoId }
        return false
    }

    var isDownloadingThis: Bool {
        controller.downloadOnlyProgress?.model == model.repoId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isThisModelActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.shortName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(statusLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(isThisModelActive ? .green : .secondary)
                }
                Spacer()
                actionButtons
            }

            if isThisModelActive, let config = controller.activeConfig {
                statsRow(config: config)
            }
        }
        .padding(isThisModelActive ? 8 : 0)
        .background {
            if isThisModelActive {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.12))
            }
        }
        .confirmationDialog(
            "¿Borrar \(model.shortName) del disco?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Borrar", role: .destructive) {
                _ = controller.delete(model.repoId)
                modelsVM.refresh()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Libera espacio en disco. Vas a tener que volver a bajarlo si lo necesitás después.")
        }
    }

    private var statusLabel: String {
        if isThisModelActive { return "activo" }
        return model.isInstalled ? "descargado" : "no descargado"
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isDownloadingThis {
            Text("\(controller.downloadOnlyProgress?.percent ?? 0)%")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        } else if isThisModelActive {
            Button("Detener") { controller.stop() }
                .controlSize(.small)
        } else if model.isInstalled {
            Button("Cargar") { controller.load(model.repoId) }
                .controlSize(.small)
                .disabled(isBusyElsewhere)
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .controlSize(.small)
            .disabled(isBusyElsewhere)
        } else {
            Button("Bajar") {
                controller.download(model.repoId) { _ in modelsVM.refresh() }
            }
            .controlSize(.small)
            .disabled(isBusyElsewhere)
        }
    }

    private func statsRow(config: (port: String, maxMemory: String?, maxContext: String?)) -> some View {
        HStack(spacing: 12) {
            statChip(label: "Puerto", value: config.port)
            statChip(label: "Memoria", value: config.maxMemory ?? "auto")
            statChip(label: "Contexto", value: config.maxContext ?? "auto")
        }
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 8)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 10, weight: .medium))
        }
    }

    private var isBusyElsewhere: Bool {
        if case .loading = controller.state { return true }
        if case .downloading = controller.state { return true }
        return controller.downloadOnlyProgress != nil && !isDownloadingThis
    }
}

private struct SettingsPanel: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledSizeField(
                label: "Límite memoria (Metal)",
                value: $settings.maxMemoryValue,
                unit: $settings.maxMemoryUnit
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Contexto máximo").font(.system(size: 11))
                    Spacer()
                    Toggle("Auto", isOn: $settings.contextIsAuto)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10))
                }
                if !settings.contextIsAuto {
                    LabeledSizeField(
                        label: "",
                        value: $settings.maxContextValue,
                        unit: $settings.maxContextUnit
                    )
                } else {
                    Text("Splash decide (usa el máximo del modelo cargado).")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            LabeledNumericField(label: "Puerto", placeholder: "8000", text: $settings.port, maxDigits: 5)

            Toggle("Iniciar al iniciar sesión", isOn: $settings.launchAtLogin)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.mini)

            Divider()

            Toggle("Sincronizar contexto con opencode", isOn: $settings.opencodeSyncEnabled)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.mini)

            if settings.opencodeSyncEnabled {
                TextField("~/.config/opencode/opencode.json", text: $settings.opencodeConfigPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 9))

                Text("Al cargar un modelo, actualiza el \"context\" declarado en el provider \"splash\" de opencode.json para que coincida con el límite real del server — evita el error \"prompt exceeds the context window\" cuando cambiás el contexto acá.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Tu Mac: \(settings.recommended.totalRAMGB)GB RAM")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restaurar recomendados") {
                    settings.resetToRecommendedDefaults()
                }
                .font(.system(size: 9))
                .controlSize(.mini)
            }

            Text("Recomendado para tu equipo: \(settings.recommended.memoryValue)\(settings.recommended.memoryUnit.rawValue) memoria / \(settings.recommended.contextValue)\(settings.recommended.contextUnit.rawValue) contexto. Cambios aplican en la próxima carga.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

private struct LabeledSizeField: View {
    let label: String
    @Binding var value: String
    @Binding var unit: SizeUnit

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            TextField("", text: Binding(
                get: { value },
                set: { value = filterDigits($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 50)
            .font(.system(size: 11))
            .multilineTextAlignment(.trailing)

            Picker("", selection: $unit) {
                ForEach(SizeUnit.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 90)
            .labelsHidden()
        }
    }
}

private struct LabeledNumericField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var maxDigits: Int = 10

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            TextField(placeholder, text: Binding(
                get: { text },
                set: { text = String(filterDigits($0).prefix(maxDigits)) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
            .font(.system(size: 11))
        }
    }
}
