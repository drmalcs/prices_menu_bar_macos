import Foundation

struct RealtimeData {
    let priceUSD: Double
    let priceGBP: Double
    let change1h: Double?   // % vs price 1 hour ago; nil when unavailable (AV fallback)
    let lastFetched: Date
}

struct HistoricalData {
    let change24h: Double?  // % vs previous trading day close
    let change1y: Double?   // % vs closing price ~1 year ago
    let lastFetched: Date
}
