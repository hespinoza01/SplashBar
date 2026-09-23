import Foundation

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static let repositoryURL = URL(string: "https://github.com/hespinoza01/SplashBar")!
    static let authorGitHubURL = URL(string: "https://github.com/hespinoza01")!
    static let authorHandle = "hespinoza01"

    /// Always reflects the current year rather than a value frozen at build time.
    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
}
