import Foundation

@MainActor
final class PriceService: ObservableObject {
    @Published var prices: [String: PriceData] = [:]
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var dataSource: String = ""

    private var refreshTask: Task<Void, Never>?

    func startRefreshing(items: [TrackedItem]) {
        refreshTask?.cancel()
        guard !items.isEmpty else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(items: items)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh(items: [TrackedItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        lastError = nil

        do {
            let result = try await YahooFinanceService().fetchPrices(for: items)
            prices = result
            dataSource = result.values.first?.source ?? "Yahoo Finance"
        } catch {
            // Yahoo throttled or failed — fall back to Alpha Vantage.
            do {
                let result = try await AlphaVantageService().fetchPrices(for: items)
                prices = result
                dataSource = result.values.first?.source ?? "Alpha Vantage"
            } catch let avErr {
                lastError = avErr.localizedDescription
            }
        }
        isLoading = false
    }
}
