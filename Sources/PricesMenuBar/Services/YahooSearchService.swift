import Foundation

struct YahooSearchResult: Identifiable, Decodable {
    var id: String { symbol }
    let symbol: String
    let shortname: String?
    let longname: String?
    let quoteType: String?
    let exchange: String?
    let exchDisp: String?

    var displayLabel: String { longname ?? shortname ?? symbol }
    var inferredAssetType: AssetType {
        if quoteType == "CRYPTOCURRENCY" { return .crypto }
        if symbol.hasSuffix(".L") || exchDisp?.contains("London") == true { return .ukStock }
        return .usStock
    }
}

private struct YFSearchResponse: Decodable {
    let quotes: [YahooSearchResult]?
}

struct YahooSearchService {
    func search(query: String) async throws -> [YahooSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=10&newsCount=0") else {
            throw ServiceError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YFSearchResponse.self, from: data)
        return response.quotes ?? []
    }
}
