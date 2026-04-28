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
    let marketState: MarketState
    let lastFetched: Date
}

struct HistoricalData {
    let previousClose: Double?  // previous session close, native currency (for 24h% calculation)
    let yearAgoClose: Double?   // close ~1yr ago, native currency (for 1y% calculation)
    let lastFetched: Date
}

struct ErrorEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}
