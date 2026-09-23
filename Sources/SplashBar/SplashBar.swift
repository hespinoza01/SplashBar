import SwiftUI

@main
struct SplashBarApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var controller: SplashController
    @StateObject private var modelsVM = ModelsViewModel()

    init() {
        let store = SettingsStore()
        _settings = StateObject(wrappedValue: store)
        _controller = StateObject(wrappedValue: SplashController(settings: store))
    }

    var body: some Scene {
        MenuBarExtra("SplashBar", systemImage: controller.state.menuBarSymbol) {
            ContentView()
                .environmentObject(controller)
                .environmentObject(settings)
                .environmentObject(modelsVM)
        }
        .menuBarExtraStyle(.window)
    }
}
