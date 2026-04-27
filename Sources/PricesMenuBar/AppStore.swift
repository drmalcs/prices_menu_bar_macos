import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var trackedItems: [TrackedItem] {
        didSet {
            saveItems()
            priceService.startRefreshing(items: trackedItems)
        }
    }

    let priceService = PriceService()

    init() {
        if let data = UserDefaults.standard.data(forKey: "trackedItems"),
           let saved = try? JSONDecoder().decode([TrackedItem].self, from: data) {
            trackedItems = saved
        } else {
            trackedItems = TrackedItem.defaults
        }
        // didSet doesn't fire during init, so kick off the first fetch here.
        // Task inherits @MainActor context from the enclosing class.
        Task { [weak self] in
            self?.priceService.startRefreshing(items: self?.trackedItems ?? [])
        }
    }

    func startRefreshing() {
        priceService.startRefreshing(items: trackedItems)
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(trackedItems) else { return }
        UserDefaults.standard.set(data, forKey: "trackedItems")
    }
}
