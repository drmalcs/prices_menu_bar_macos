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

    // Called on every popover open. Uses 5m/5d chart for price and accurate 1h%.
    // range=5d (not 1d) so closed exchanges always have recent bars available.
    func fetchRealtimeData(for items: [TrackedItem]) async throws -> [String: RealtimeData] {
        let gbpUSD = try await fetchGBPUSDRate()
        return try await withThrowingTaskGroup(of: (String, RealtimeData).self) { group in
            for item in items {
                group.addTask {
                    let chart = try await self.fetchChart(symbol: item.symbol, interval: "5m", range: "5d")
                    guard let result = chart.chart.result?.first else {
                        throw ServiceError.invalidResponse("No realtime data for \(item.symbol)")
                    }
                    let timestamps = result.timestamp ?? []
                    let allCloses = result.indicators.quote.first?.close ?? []

                    // Use the official regular-market price (live intraday or last close).
                    let current = result.meta.regularMarketPrice
                    guard current > 0 else {
                        throw ServiceError.invalidResponse("No regular market price for \(item.symbol)")
                    }

                    let now = Int(Date().timeIntervalSince1970)

                    // Market state — crypto is always open; stocks use the trading-period window.
                    let marketState: MarketState
                    if item.assetType == .crypto {
                        marketState = .open
                    } else if let r = result.meta.currentTradingPeriod?.regular,
                              now >= r.start && now <= r.end {
                        marketState = (now - r.start) < 3600 ? .openLessThan1h : .open
                    } else {
                        marketState = .closed
                    }

                    // 1h reference: last bar at or before (now - 3600s).
                    // 5m bars mean this is within 5 min of a true 60-min lookback for any symbol.
                    let target = now - 3600
                    let refBar = zip(timestamps, allCloses)
                        .filter { $0.0 <= target }
                        .compactMap { ts, c -> (Int, Double)? in c.map { (ts, $0) } }
                        .last

                    let change1h: Double?
                    if let (_, refPrice) = refBar, refPrice > 0 {
                        change1h = (current - refPrice) / refPrice * 100
                    } else {
                        change1h = nil
                    }

                    let priceGBP = self.toGBP(price: current, currency: result.meta.currency, gbpUSD: gbpUSD)
                    return (item.symbol, RealtimeData(
                        priceUSD: current, priceGBP: priceGBP, change1h: change1h,
                        marketState: marketState, lastFetched: Date()
                    ))
                }
            }
            var out: [String: RealtimeData] = [:]
            for try await (sym, data) in group { out[sym] = data }
            return out
        }
    }

    // Called on every popover open and when items change.
    // Returns previous session close and year-ago close as raw prices.
    func fetchHistoricalData(for items: [TrackedItem]) async throws -> [String: HistoricalData] {
        return try await withThrowingTaskGroup(of: (String, HistoricalData).self) { group in
            for item in items {
                group.addTask {
                    let chart = try await self.fetchChart(symbol: item.symbol, interval: "1d", range: "1y")
                    guard let result = chart.chart.result?.first else {
                        throw ServiceError.invalidResponse("No historical data for \(item.symbol)")
                    }
                    let closes = result.indicators.quote.first?.close.compactMap { $0 } ?? []

                    // closes[-1] is either today's partial/complete bar or the last completed
                    // session — either way, closes[-2] is always the session before that,
                    // which is what we want as the reference for 24h% calculation.
                    let previousClose: Double? = closes.count >= 2 ? closes[closes.count - 2] : nil

                    return (item.symbol, HistoricalData(
                        previousClose: previousClose,
                        yearAgoClose: closes.first,
                        lastFetched: Date()
                    ))
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
    let timestamp: [Int]?
    let indicators: YFIndicators
}
struct YFTradingPeriod: Decodable {
    let start: Int
    let end: Int
}
struct YFCurrentTradingPeriod: Decodable {
    let regular: YFTradingPeriod
}
struct YFMeta: Decodable {
    let symbol: String
    let currency: String?
    let regularMarketPrice: Double
    let regularMarketTime: Int
    let currentTradingPeriod: YFCurrentTradingPeriod?
}
struct YFIndicators: Decodable {
    let quote: [YFQuote]
}
struct YFQuote: Decodable {
    let close: [Double?]
}
