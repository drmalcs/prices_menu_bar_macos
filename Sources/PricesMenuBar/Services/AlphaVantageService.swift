import Foundation

// Fallback data source when Yahoo Finance throttles or fails.
// Provides current price + 24hr change for all asset types, and 1yr change via daily history.
// 1hr change is unavailable from basic AV endpoints and will be nil.
struct AlphaVantageService {
    private let base = "https://www.alphavantage.co/query"

    func fetchPrices(for items: [TrackedItem]) async throws -> [String: PriceData] {
        let key = Config.alphaVantageKey
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }

        let gbpUSD = try await fetchGBPUSDRate(key: key)

        // Sequential to respect rate limits on free tier.
        var results: [String: PriceData] = [:]
        for item in items {
            if let data = try? await fetchItemData(item: item, gbpUSD: gbpUSD, key: key) {
                results[item.symbol] = data
            }
        }
        return results
    }

    // MARK: - Private

    private func fetchGBPUSDRate(key: String) async throws -> Double {
        let data = try await get(params: [
            "function": "CURRENCY_EXCHANGE_RATE",
            "from_currency": "GBP",
            "to_currency": "USD",
            "apikey": key,
        ])
        let r = try JSONDecoder().decode(AVExchangeRateResponse.self, from: data)
        guard let s = r.rate?.exchangeRate, let v = Double(s), v > 0 else {
            throw ServiceError.invalidResponse("No GBP/USD from Alpha Vantage")
        }
        return v
    }

    private func fetchItemData(item: TrackedItem, gbpUSD: Double, key: String) async throws -> PriceData {
        let (current, change24h, currency) = try await fetchCurrentQuote(item: item, key: key)
        let change1y = try? await fetchOneYearChange(item: item, current: current, key: key)

        let priceGBP: Double
        switch currency.uppercased() {
        case "GBX": priceGBP = current / 100
        case "GBP": priceGBP = current
        default:    priceGBP = current / gbpUSD
        }

        return PriceData(
            symbol: item.symbol,
            priceUSD: current,
            priceGBP: priceGBP,
            change1h: nil,
            change24h: change24h,
            change1y: change1y,
            source: "Alpha Vantage",
            lastUpdated: Date()
        )
    }

    private func fetchCurrentQuote(item: TrackedItem, key: String) async throws -> (Double, Double?, String) {
        if item.assetType == .crypto {
            return try await fetchCryptoRate(item: item, key: key)
        } else {
            return try await fetchStockQuote(item: item, key: key)
        }
    }

    private func fetchStockQuote(item: TrackedItem, key: String) async throws -> (Double, Double?, String) {
        // AV uses plain ticker without .L suffix; it infers the exchange.
        let sym = item.symbol.hasSuffix(".L") ? String(item.symbol.dropLast(2)) : item.symbol
        let data = try await get(params: ["function": "GLOBAL_QUOTE", "symbol": sym, "apikey": key])
        let r = try JSONDecoder().decode(AVGlobalQuoteResponse.self, from: data)
        guard let q = r.globalQuote, let ps = q.price, let price = Double(ps) else {
            throw ServiceError.invalidResponse("No quote for \(item.symbol)")
        }
        let change = q.changePercent
            .flatMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        let currency = item.assetType == .ukStock ? "GBX" : "USD"
        return (price, change, currency)
    }

    private func fetchCryptoRate(item: TrackedItem, key: String) async throws -> (Double, Double?, String) {
        let from = item.symbol.components(separatedBy: "-").first ?? item.symbol
        let data = try await get(params: [
            "function": "CURRENCY_EXCHANGE_RATE",
            "from_currency": from,
            "to_currency": "USD",
            "apikey": key,
        ])
        let r = try JSONDecoder().decode(AVExchangeRateResponse.self, from: data)
        guard let s = r.rate?.exchangeRate, let price = Double(s) else {
            throw ServiceError.invalidResponse("No crypto rate for \(item.symbol)")
        }
        return (price, nil, "USD")
    }

    private func fetchOneYearChange(item: TrackedItem, current: Double, key: String) async throws -> Double {
        if item.assetType == .crypto {
            let sym = item.symbol.components(separatedBy: "-").first ?? item.symbol
            let data = try await get(params: [
                "function": "DIGITAL_CURRENCY_DAILY",
                "symbol": sym,
                "market": "USD",
                "apikey": key,
            ])
            let r = try JSONDecoder().decode(AVCryptoDailyResponse.self, from: data)
            guard let series = r.timeSeries, let oldEntry = series[series.keys.sorted().first ?? ""],
                  let s = oldEntry["4a. close (USD)"], let old = Double(s), old > 0 else {
                throw ServiceError.noData
            }
            return (current - old) / old * 100
        } else {
            let sym = item.symbol.hasSuffix(".L") ? String(item.symbol.dropLast(2)) : item.symbol
            let data = try await get(params: [
                "function": "TIME_SERIES_DAILY",
                "symbol": sym,
                "outputsize": "full",
                "apikey": key,
            ])
            let r = try JSONDecoder().decode(AVDailyResponse.self, from: data)
            guard let series = r.timeSeries, let oldEntry = series[series.keys.sorted().first ?? ""],
                  let s = oldEntry["4. close"], let old = Double(s), old > 0 else {
                throw ServiceError.noData
            }
            return (current - old) / old * 100
        }
    }

    private func get(params: [String: String]) async throws -> Data {
        var components = URLComponents(string: base)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw ServiceError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.httpError(http.statusCode)
        }
        return data
    }
}

// MARK: - Response types

struct AVGlobalQuoteResponse: Decodable {
    let globalQuote: AVGlobalQuote?
    enum CodingKeys: String, CodingKey { case globalQuote = "Global Quote" }
}
struct AVGlobalQuote: Decodable {
    let price: String?
    let changePercent: String?
    enum CodingKeys: String, CodingKey {
        case price = "05. price"
        case changePercent = "10. change percent"
    }
}
struct AVExchangeRateResponse: Decodable {
    let rate: AVExchangeRate?
    enum CodingKeys: String, CodingKey { case rate = "Realtime Currency Exchange Rate" }
}
struct AVExchangeRate: Decodable {
    let exchangeRate: String?
    enum CodingKeys: String, CodingKey { case exchangeRate = "5. Exchange Rate" }
}
struct AVDailyResponse: Decodable {
    let timeSeries: [String: [String: String]]?
    enum CodingKeys: String, CodingKey { case timeSeries = "Time Series (Daily)" }
}
struct AVCryptoDailyResponse: Decodable {
    let timeSeries: [String: [String: String]]?
    enum CodingKeys: String, CodingKey { case timeSeries = "Time Series (Digital Currency Daily)" }
}
