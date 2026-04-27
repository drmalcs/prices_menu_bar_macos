import Foundation

@MainActor
final class PriceService: ObservableObject {
    @Published var realtime:            [String: RealtimeData]  = [:]
    @Published var historical:          [String: HistoricalData] = [:]
    @Published var isLoadingRealtime:   Bool = false
    @Published var isLoadingHistorical: Bool = false
    @Published var dataSource:          String = ""
    @Published var errorLog:            [ErrorEntry] = []

    private let maxLogEntries = 50

    func fetchRealtime(items: [TrackedItem]) async {
        guard !items.isEmpty, !isLoadingRealtime else { return }
        isLoadingRealtime = true
        do {
            let result = try await YahooFinanceService().fetchRealtimeData(for: items)
            realtime = result
            dataSource = "Yahoo Finance"
        } catch {
            appendError("Yahoo Finance: \(error.localizedDescription)")
            do {
                let result = try await AlphaVantageService().fetchRealtimeData(for: items)
                realtime = result
                dataSource = "Alpha Vantage"
            } catch let avErr {
                appendError("Alpha Vantage: \(avErr.localizedDescription)")
            }
        }
        isLoadingRealtime = false
    }

    func fetchHistorical(items: [TrackedItem]) async {
        guard !items.isEmpty, !isLoadingHistorical else { return }
        isLoadingHistorical = true
        do {
            let result = try await YahooFinanceService().fetchHistoricalData(for: items)
            historical = result
        } catch {
            appendError("Yahoo Finance (historical): \(error.localizedDescription)")
            do {
                let result = try await AlphaVantageService().fetchHistoricalData(for: items)
                historical = result
            } catch let avErr {
                appendError("Alpha Vantage (historical): \(avErr.localizedDescription)")
            }
        }
        isLoadingHistorical = false
    }

    private func appendError(_ message: String) {
        errorLog.append(ErrorEntry(timestamp: Date(), message: message))
        if errorLog.count > maxLogEntries {
            errorLog.removeFirst(errorLog.count - maxLogEntries)
        }
    }
}
