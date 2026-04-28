import Foundation

enum AssetType: String, Codable, CaseIterable {
    case crypto = "Crypto"
    case usStock = "US Stock"
    case ukStock = "UK Stock (LSE)"
}

struct TrackedItem: Identifiable, Codable, Equatable {
    let id: UUID
    var symbol: String
    var displayName: String
    var assetType: AssetType
    var quantity: Double
    var taxRate: Double     // percentage, e.g. 20.0 → Val × (1 − 0.20)

    init(symbol: String, displayName: String, assetType: AssetType,
         quantity: Double = 0, taxRate: Double = 0) {
        self.id = UUID()
        self.symbol = symbol
        self.displayName = displayName
        self.assetType = assetType
        self.quantity = quantity
        self.taxRate = taxRate
    }

    // Custom decoding so existing saved items (missing taxRate) decode as 0.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,      forKey: .id)
        symbol      = try c.decode(String.self,    forKey: .symbol)
        displayName = try c.decode(String.self,    forKey: .displayName)
        assetType   = try c.decode(AssetType.self, forKey: .assetType)
        quantity    = try c.decode(Double.self,    forKey: .quantity)
        taxRate     = (try? c.decode(Double.self,  forKey: .taxRate)) ?? 0
    }

    static let defaults: [TrackedItem] = [
        TrackedItem(symbol: "BTC-USD", displayName: "BTC", assetType: .crypto),
        TrackedItem(symbol: "ETH-USD", displayName: "ETH", assetType: .crypto),
    ]
}
