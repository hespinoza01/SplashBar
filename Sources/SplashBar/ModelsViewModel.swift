import Foundation
import Combine

@MainActor
final class ModelsViewModel: ObservableObject {
    @Published var models: [ModelEntry] = []

    init() { refresh() }

    func refresh() {
        models = ModelCatalog.all()
    }
}
