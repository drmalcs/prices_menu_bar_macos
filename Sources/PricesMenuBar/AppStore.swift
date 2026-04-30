import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var trackedItems: [TrackedItem] {
        didSet {
            saveItems()
            let oldSymbols = Set(oldValue.map(\.symbol))
            let newSymbols = Set(trackedItems.map(\.symbol))
            if oldSymbols != newSymbols {
                Task { await priceService.fetchHistorical(items: trackedItems) }
            }
        }
    }

    let priceService = PriceService()
    private var serviceObserver: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: "trackedItems"),
           let saved = try? JSONDecoder().decode([TrackedItem].self, from: data) {
            trackedItems = saved
        } else {
            trackedItems = TrackedItem.defaults
        }
        serviceObserver = priceService.objectWillChange.sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.objectWillChange.send()
            }
        }
        // Load historical data (including P/E) once at startup.
        Task { [weak self] in
            guard let self else { return }
            await priceService.fetchHistorical(items: trackedItems)
        }
        // Background realtime refresh while panel is closed.
        startRefreshLoop(interval: 600)
    }

    // MARK: - Panel lifecycle

    func panelOpened() {
        Task { await priceService.fetchRealtime(items: trackedItems) }
        Task { await priceService.fetchHistorical(items: trackedItems) }
        startRefreshLoop(interval: 30)
    }

    func panelClosed() {
        startRefreshLoop(interval: 600)
    }

    // MARK: - Refresh loop

    private func startRefreshLoop(interval: TimeInterval) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await priceService.fetchRealtime(items: trackedItems)
            }
        }
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(trackedItems) else { return }
        UserDefaults.standard.set(data, forKey: "trackedItems")
    }
}
