import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "drop.circle.fill")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.cyan)
            }

            VStack(spacing: 2) {
                Text("SplashBar")
                    .font(.system(size: 18, weight: .semibold))
                Text("Versión \(AppInfo.version) (build \(AppInfo.buildNumber))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Gestor de barra de menú para Splash, el motor de inferencia local de Apple Silicon.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 260)

            Divider()

            VStack(spacing: 6) {
                Link(destination: AppInfo.repositoryURL) {
                    Label("Repositorio en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11))
                }
                Link(destination: AppInfo.authorGitHubURL) {
                    Label("@\(AppInfo.authorHandle)", systemImage: "person.circle")
                        .font(.system(size: 11))
                }
            }

            Text("© \(String(AppInfo.currentYear)) \(AppInfo.authorHandle). Código abierto bajo MIT.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 320)
    }
}
