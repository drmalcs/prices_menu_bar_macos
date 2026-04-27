import Foundation

enum ServiceError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case invalidResponse(String)
    case missingAPIKey
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid URL"
        case .httpError(let code):     return "HTTP \(code)"
        case .invalidResponse(let m):  return m
        case .missingAPIKey:           return "Alpha Vantage key not set"
        case .noData:                  return "No data"
        }
    }
}
