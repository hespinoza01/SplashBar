import Foundation

enum SizeUnit: String, CaseIterable, Identifiable {
    case k = "K"
    case m = "M"
    case g = "G"

    var id: String { rawValue }
}
