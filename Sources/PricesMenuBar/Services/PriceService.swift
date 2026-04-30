import Foundation

@MainActor
final class PriceService: ObservableObject {
    @Published var realtime:            [String: RealtimeData]  = [:]
    @Published var historical:          [String: HistoricalData] = [:]
    @Published var isLoadingRealtime:   Bool = false
    @Published var isLoadingHistorical: Bool = false
    @Published var dataSource:          String = ""
    @Published var errorLog:            [ErrorEntry] = []

    private let maxLogEntries = 50

    func fetchRealtime(items: [TrackedItem]) async {
        guard !items.isEmpty, !isLoadingRealtime else { return }
        isLoadingRealtime = true
        do {
            let result = try await YahooFinanceService().fetchRealtimeData(for: items)
            realtime = result
            dataSource = "Yahoo Finance"
            errorLog.removeAll()
        } catch {
            if error is CancellationError { isLoadingRealtime = false; return }
            appendError("Yahoo Finance: \(error.localizedDescription)")
            do {
                let result = try await AlphaVantageService().fetchRealtimeData(for: items)
                realtime = result
                dataSource = "Alpha Vantage"
            } catch let avErr {
                appendError("Alpha Vantage: \(avErr.localizedDescription)")
            }
        }
        isLoadingRealtime = false
    }

    func fetchHistorical(items: [TrackedItem]) async {
        guard !items.isEmpty, !isLoadingHistorical else { return }
        isLoadingHistorical = true
        do {
            let result = try await YahooFinanceService().fetchHistoricalData(for: items)
            historical = preservingEPS(result)
        } catch {
            if error is CancellationError { isLoadingHistorical = false; return }
            appendError("Yahoo Finance (historical): \(error.localizedDescription)")
            do {
                let result = try await AlphaVantageService().fetchHistoricalData(for: items)
                historical = preservingEPS(result)
            } catch let avErr {
                appendError("Alpha Vantage (historical): \(avErr.localizedDescription)")
            }
        }
        isLoadingHistorical = false
        // Fetch EPS in background: sequential to respect AV's 5 req/min limit.
        Task { await self.fetchMissingEPS(items: items) }
    }

    // Merges new historical data without losing EPS values already fetched from AV.
    private func preservingEPS(_ new: [String: HistoricalData]) -> [String: HistoricalData] {
        var merged = new
        for symbol in new.keys {
            if let eps = historical[symbol]?.trailingEps {
                merged[symbol]?.trailingEps = eps
            }
        }
        return merged
    }

    // Fetches EPS from AV OVERVIEW for any stock that doesn't have it yet.
    // One request every 13 s to stay within the free-tier 5 req/min limit.
    // Assumption: AV returns EPS in the stock's native currency (GBX for LSE stocks).
    // If UK P/E looks 100x too high, multiply eps by 0.01 here for ukStock items.
    private func fetchMissingEPS(items: [TrackedItem]) async {
        let key = Config.alphaVantageKey
        guard !key.isEmpty else { return }

        let needed = items.filter {
            $0.assetType != .crypto && historical[$0.symbol]?.trailingEps == nil
        }
        guard !needed.isEmpty else { return }

        let service = AlphaVantageService()
        for (index, item) in needed.enumerated() {
            if index > 0 { try? await Task.sleep(for: .seconds(13)) }
            let sym = item.symbol.hasSuffix(".L") ? String(item.symbol.dropLast(2)) : item.symbol
            if let eps = try? await service.fetchEPS(symbol: sym, key: key) {
                historical[item.symbol]?.trailingEps = eps
            }
        }
    }

    private func appendError(_ message: String) {
        errorLog.append(ErrorEntry(timestamp: Date(), message: message))
        if errorLog.count > maxLogEntries {
            errorLog.removeFirst(errorLog.count - maxLogEntries)
        }
    }
}
