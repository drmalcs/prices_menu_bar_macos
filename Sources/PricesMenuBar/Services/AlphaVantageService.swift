import Foundation

// Fallback when Yahoo Finance fails. Sequential fetches to respect rate limits.
// 1h change is unavailable from basic AV endpoints — always nil.
struct AlphaVantageService {
    private let base = "https://www.alphavantage.co/query"

    func fetchRealtimeData(for items: [TrackedItem]) async throws -> [String: RealtimeData] {
        let key = Config.alphaVantageKey
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }
        let gbpUSD = try await fetchGBPUSDRate(key: key)
        var out: [String: RealtimeData] = [:]
        for item in items {
            if let data = try? await fetchItemRealtime(item: item, gbpUSD: gbpUSD, key: key) {
                out[item.symbol] = data
            }
        }
        return out
    }

    func fetchHistoricalData(for items: [TrackedItem]) async throws -> [String: HistoricalData] {
        let key = Config.alphaVantageKey
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }
        var out: [String: HistoricalData] = [:]
        for item in items {
            if let data = try? await fetchItemHistorical(item: item, key: key) {
                out[item.symbol] = data
            }
        }
        return out
    }

    // MARK: - Realtime

    private func fetchGBPUSDRate(key: String) async throws -> Double {
        let data = try await get(params: [
            "function": "CURRENCY_EXCHANGE_RATE",
            "from_currency": "GBP", "to_currency": "USD", "apikey": key,
        ])
        let r = try JSONDecoder().decode(AVExchangeRateResponse.self, from: data)
        guard let s = r.rate?.exchangeRate, let v = Double(s), v > 0 else {
            throw ServiceError.invalidResponse("No GBP/USD from Alpha Vantage")
        }
        return v
    }

    private func fetchItemRealtime(item: TrackedItem, gbpUSD: Double, key: String) async throws -> RealtimeData {
        let (price, currency) = try await fetchCurrentPrice(item: item, key: key)
        let priceGBP: Double
        switch currency.uppercased() {
        case "GBX": priceGBP = price / 100
        case "GBP": priceGBP = price
        default:    priceGBP = price / gbpUSD
        }
        return RealtimeData(priceUSD: price, priceGBP: priceGBP, change1h: nil, lastFetched: Date())
    }

    private func fetchCurrentPrice(item: TrackedItem, key: String) async throws -> (Double, String) {
        if item.assetType == .crypto {
            let from = item.symbol.components(separatedBy: "-").first ?? item.symbol
            let data = try await get(params: [
                "function": "CURRENCY_EXCHANGE_RATE",
                "from_currency": from, "to_currency": "USD", "apikey": key,
            ])
            let r = try JSONDecoder().decode(AVExchangeRateResponse.self, from: data)
            guard let s = r.rate?.exchangeRate, let price = Double(s) else {
                throw ServiceError.invalidResponse("No crypto rate for \(item.symbol)")
            }
            return (price, "USD")
        } else {
            let sym = item.symbol.hasSuffix(".L") ? String(item.symbol.dropLast(2)) : item.symbol
            let data = try await get(params: ["function": "GLOBAL_QUOTE", "symbol": sym, "apikey": key])
            let r = try JSONDecoder().decode(AVGlobalQuoteResponse.self, from: data)
            guard let q = r.globalQuote, let ps = q.price, let price = Double(ps) else {
                throw ServiceError.invalidResponse("No quote for \(item.symbol)")
            }
            return (price, item.assetType == .ukStock ? "GBX" : "USD")
        }
    }

    // MARK: - Historical

    private func fetchItemHistorical(item: TrackedItem, key: String) async throws -> HistoricalData {
        if item.assetType == .crypto {
            let sym = item.symbol.components(separatedBy: "-").first ?? item.symbol
            let data = try await get(params: [
                "function": "DIGITAL_CURRENCY_DAILY", "symbol": sym, "market": "USD", "apikey": key,
            ])
            let r = try JSONDecoder().decode(AVCryptoDailyResponse.self, from: data)
            guard let series = r.timeSeries else { throw ServiceError.noData }
            let sorted = series.keys.sorted()
            guard sorted.count >= 2,
                  let lastEntry  = series[sorted.last ?? ""],
                  let prevEntry  = series[sorted[sorted.count - 2]],
                  let lastPrice  = lastEntry["4a. close (USD)"].flatMap(Double.init),
                  let prevPrice  = prevEntry["4a. close (USD)"].flatMap(Double.init),
                  let firstEntry = series[sorted.first ?? ""],
                  let yearPrice  = firstEntry["4a. close (USD)"].flatMap(Double.init),
                  prevPrice > 0, yearPrice > 0 else { throw ServiceError.noData }
            return HistoricalData(
                change24h: (lastPrice - prevPrice) / prevPrice * 100,
                change1y:  (lastPrice - yearPrice) / yearPrice * 100,
                lastFetched: Date()
            )
        } else {
            let sym = item.symbol.hasSuffix(".L") ? String(item.symbol.dropLast(2)) : item.symbol
            let data = try await get(params: [
                "function": "TIME_SERIES_DAILY", "symbol": sym, "outputsize": "full", "apikey": key,
            ])
            let r = try JSONDecoder().decode(AVDailyResponse.self, from: data)
            guard let series = r.timeSeries else { throw ServiceError.noData }
            let sorted = series.keys.sorted()
            guard sorted.count >= 2,
                  let lastEntry  = series[sorted.last ?? ""],
                  let prevEntry  = series[sorted[sorted.count - 2]],
                  let lastPrice  = lastEntry["4. close"].flatMap(Double.init),
                  let prevPrice  = prevEntry["4. close"].flatMap(Double.init),
                  let firstEntry = series[sorted.first ?? ""],
                  let yearPrice  = firstEntry["4. close"].flatMap(Double.init),
                  prevPrice > 0, yearPrice > 0 else { throw ServiceError.noData }
            return HistoricalData(
                change24h: (lastPrice - prevPrice) / prevPrice * 100,
                change1y:  (lastPrice - yearPrice) / yearPrice * 100,
                lastFetched: Date()
            )
        }
    }

    // MARK: - HTTP helper

    private func get(params: [String: String]) async throws -> Data {
        var comps = URLComponents(string: base)!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw ServiceError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.httpError(http.statusCode)
        }
        return data
    }
}

// MARK: - Response types

private struct AVGlobalQuoteResponse: Decodable {
    let globalQuote: AVGlobalQuote?
    enum CodingKeys: String, CodingKey { case globalQuote = "Global Quote" }
}
private struct AVGlobalQuote: Decodable {
    let price: String?
    enum CodingKeys: String, CodingKey { case price = "05. price" }
}
private struct AVExchangeRateResponse: Decodable {
    let rate: AVExchangeRate?
    enum CodingKeys: String, CodingKey { case rate = "Realtime Currency Exchange Rate" }
}
private struct AVExchangeRate: Decodable {
    let exchangeRate: String?
    enum CodingKeys: String, CodingKey { case exchangeRate = "5. Exchange Rate" }
}
private struct AVDailyResponse: Decodable {
    let timeSeries: [String: [String: String]]?
    enum CodingKeys: String, CodingKey { case timeSeries = "Time Series (Daily)" }
}
private struct AVCryptoDailyResponse: Decodable {
    let timeSeries: [String: [String: String]]?
    enum CodingKeys: String, CodingKey { case timeSeries = "Time Series (Digital Currency Daily)" }
}
