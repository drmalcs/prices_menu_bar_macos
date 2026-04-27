import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var trackedItems: [TrackedItem] {
        didSet {
            saveItems()
            Task { await priceService.fetchHistorical(items: trackedItems) }
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
        Task { [weak self] in
            guard let self else { return }
            await self.priceService.fetchHistorical(items: self.trackedItems)
        }
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(trackedItems) else { return }
        UserDefaults.standard.set(data, forKey: "trackedItems")
    }
}
