import Foundation

enum AssetType: String, Codable, CaseIterable {
    case crypto = "Crypto"
    case usStock = "US Stock"
    case ukStock = "UK Stock (LSE)"
}

struct TrackedItem: Identifiable, Codable, Equatable {
    let id: UUID
    var symbol: String       // Yahoo Finance ticker: BTC-USD, AAPL, LLOY.L
    var displayName: String  // Short label shown in the row
    var assetType: AssetType
    var quantity: Double     // Multiplied by GBP price to produce Val

    init(symbol: String, displayName: String, assetType: AssetType, quantity: Double = 0) {
        self.id = UUID()
        self.symbol = symbol
        self.displayName = displayName
        self.assetType = assetType
        self.quantity = quantity
    }

    static let defaults: [TrackedItem] = [
        TrackedItem(symbol: "BTC-USD", displayName: "BTC", assetType: .crypto),
        TrackedItem(symbol: "ETH-USD", displayName: "ETH", assetType: .crypto),
    ]
}
