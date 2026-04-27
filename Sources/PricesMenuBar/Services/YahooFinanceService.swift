import Foundation

struct YahooFinanceService {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        return URLSession(configuration: cfg)
    }()

    // Called on every popover open. Uses 1h/2d chart: last close = current, second-to-last = 1hr ago.
    func fetchRealtimeData(for items: [TrackedItem]) async throws -> [String: RealtimeData] {
        let gbpUSD = try await fetchGBPUSDRate()
        return try await withThrowingTaskGroup(of: (String, RealtimeData).self) { group in
            for item in items {
                group.addTask {
                    let chart = try await self.fetchChart(symbol: item.symbol, interval: "1h", range: "2d")
                    guard let result = chart.chart.result?.first else {
                        throw ServiceError.invalidResponse("No realtime data for \(item.symbol)")
                    }
                    let closes = result.indicators.quote.first?.close.compactMap { $0 } ?? []
                    guard let current = closes.last else {
                        throw ServiceError.invalidResponse("No closes for \(item.symbol)")
                    }
                    let change1h: Double? = closes.count >= 2
                        ? { let p = closes[closes.count - 2]; return p > 0 ? (current - p) / p * 100 : nil }()
                        : nil
                    let priceGBP = self.toGBP(price: current, currency: result.meta.currency, gbpUSD: gbpUSD)
                    return (item.symbol, RealtimeData(priceUSD: current, priceGBP: priceGBP, change1h: change1h, lastFetched: Date()))
                }
            }
            var out: [String: RealtimeData] = [:]
            for try await (sym, data) in group { out[sym] = data }
            return out
        }
    }

    // Called at startup and when items change. Uses 1d/1y chart: prev close + 1yr-ago close.
    func fetchHistoricalData(for items: [TrackedItem]) async throws -> [String: HistoricalData] {
        return try await withThrowingTaskGroup(of: (String, HistoricalData).self) { group in
            for item in items {
                group.addTask {
                    let chart = try await self.fetchChart(symbol: item.symbol, interval: "1d", range: "1y")
                    guard let result = chart.chart.result?.first else {
                        throw ServiceError.invalidResponse("No historical data for \(item.symbol)")
                    }
                    let meta = result.meta
                    let closes = result.indicators.quote.first?.close.compactMap { $0 } ?? []

                    // 24h: current vs previous trading day close
                    let change24h: Double? = meta.chartPreviousClose.flatMap { prev in
                        guard prev > 0, let last = closes.last else { return nil }
                        return (last - prev) / prev * 100
                    }

                    // 1y: current vs first close in the 1-year range
                    let firstClose: Double? = closes.first
                    let change1y: Double? = firstClose.flatMap { first in
                        guard first > 0, let last = closes.last else { return nil }
                        return (last - first) / first * 100
                    }

                    return (item.symbol, HistoricalData(change24h: change24h, change1y: change1y, lastFetched: Date()))
                }
            }
            var out: [String: HistoricalData] = [:]
            for try await (sym, data) in group { out[sym] = data }
            return out
        }
    }

    // MARK: - Private helpers

    private func fetchGBPUSDRate() async throws -> Double {
        let chart = try await fetchChart(symbol: "GBPUSD=X", interval: "1d", range: "5d")
        guard let price = chart.chart.result?.first?.meta.regularMarketPrice, price > 0 else {
            throw ServiceError.invalidResponse("No GBP/USD rate")
        }
        return price
    }

    private func toGBP(price: Double, currency: String?, gbpUSD: Double) -> Double {
        switch (currency ?? "USD").uppercased() {
        case "GBX": return price / 100
        case "GBP": return price
        default:    return price / gbpUSD
        }
    }

    private func fetchChart(symbol: String, interval: String, range: String) async throws -> YFChartResponse {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=\(interval)&range=\(range)&includePrePost=false") else {
            throw ServiceError.invalidURL
        }
        let (data, response) = try await Self.session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw ServiceError.httpError(429)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.httpError(http.statusCode)
        }
        return try JSONDecoder().decode(YFChartResponse.self, from: data)
    }
}

// MARK: - Response types

struct YFChartResponse: Decodable {
    let chart: YFChartContainer
}
struct YFChartContainer: Decodable {
    let result: [YFChartResult]?
}
struct YFChartResult: Decodable {
    let meta: YFMeta
    let indicators: YFIndicators
}
struct YFMeta: Decodable {
    let symbol: String
    let currency: String?
    let regularMarketPrice: Double
    let chartPreviousClose: Double?
}
struct YFIndicators: Decodable {
    let quote: [YFQuote]
}
struct YFQuote: Decodable {
    let close: [Double?]
}
