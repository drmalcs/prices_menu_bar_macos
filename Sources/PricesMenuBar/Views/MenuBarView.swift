import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var showingErrorLog = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if Config.alphaVantageKey.isEmpty && store.trackedItems.contains(where: { $0.assetType != .crypto }) {
                avKeyWarning
                Divider()
            }
            if showingErrorLog {
                ErrorLogView().environmentObject(store)
            } else {
                PriceHeaderView()
                Divider()
                itemList
            }
        }
        .frame(width: 560)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onAppear { store.panelOpened() }
        .onDisappear { store.panelClosed() }
        .onChange(of: store.priceService.errorLog.isEmpty) { _, isEmpty in
            if isEmpty { showingErrorLog = false }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit")

            Text("PRICES").font(.custom("Baskerville-BoldItalic", size: 14))
            if store.priceService.isLoadingRealtime {
                let hasPrior = !store.priceService.realtime.isEmpty
                RefreshingLabel(text: hasPrior ? "Refreshing Data" : "Fetching data")
            } else if store.priceService.realtime.isEmpty && store.priceService.errorLog.isEmpty {
                RefreshingLabel(text: "Fetching data")
            } else if !store.priceService.errorLog.isEmpty {
                Button { showingErrorLog.toggle() } label: {
                    Text(store.priceService.errorLog.last?.message ?? "Error")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Tap to view error log")
            } else if !store.priceService.dataSource.isEmpty {
                Text("via \(store.priceService.dataSource)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                Task { await store.priceService.fetchRealtime(items: store.trackedItems) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.priceService.isLoadingRealtime)
            .help("Refresh prices")

            Button {
                NSApp.activate()
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - AV key warning

    private var avKeyWarning: some View {
        Button {
            NSApp.activate()
            openWindow(id: "settings")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text("Alpha Vantage key needed for P/E — see Settings")
                    .font(.caption)
            }
            .foregroundStyle(Theme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Item list

    @ViewBuilder
    private var itemList: some View {
        if store.trackedItems.isEmpty {
            Text("No items tracked — open Settings to add some.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ForEach(store.trackedItems) { item in
                PriceRowView(
                    item: item,
                    realtime: store.priceService.realtime[item.symbol],
                    historical: store.priceService.historical[item.symbol],
                    isStale: store.priceService.isLoadingRealtime
                        && store.priceService.realtime[item.symbol] != nil,
                    isHistoricalStale: store.priceService.isLoadingHistorical
                        && store.priceService.historical[item.symbol] != nil,
                    isLoading: store.priceService.realtime[item.symbol] == nil
                        && (store.priceService.isLoadingRealtime || store.priceService.errorLog.isEmpty)
                )
                if item.id != store.trackedItems.last?.id {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
    }
}

private struct RefreshingLabel: View {
    let text: String
    @State private var dotCount = 1

    var body: some View {
        Text(text + String(repeating: ".", count: dotCount))
            .font(.caption)
            .foregroundStyle(Theme.warning)
            .onReceive(Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
