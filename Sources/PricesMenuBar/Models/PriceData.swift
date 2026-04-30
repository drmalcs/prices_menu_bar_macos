import Foundation

enum MarketState: Equatable {
    case openLessThan1h     // regular session started < 3600 s ago
    case open               // regular session open ≥ 3600 s
    case closed             // not in regular session
}

struct RealtimeData {
    let priceUSD: Double    // native currency price (GBX for UK stocks, USD for others)
    let priceGBP: Double
    let change1h: Double?   // % vs 1hr ago; nil when AV fallback
    let tradingPeriodStart: Int?   // nil for crypto / AV fallback
    let tradingPeriodEnd: Int?     // nil for crypto / AV fallback
    let lastFetched: Date

    // Computed from current Date() so market state is never stale between fetches.
    var marketState: MarketState {
        guard let start = tradingPeriodStart, let end = tradingPeriodEnd else {
            return .open   // crypto trades 24/7
        }
        let now = Int(Date().timeIntervalSince1970)
        guard now >= start && now <= end else { return .closed }
        return (now - start) < 3600 ? .openLessThan1h : .open
    }
}

struct HistoricalData {
    let previousClose: Double?  // previous session close, native currency (for 24h% calculation)
    let yearAgoClose: Double?   // close ~1yr ago, native currency (for 1y% calculation)
    var trailingEps: Double?    // nil for crypto or until AV OVERVIEW fetch completes
    let lastFetched: Date
}

struct ErrorEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}
