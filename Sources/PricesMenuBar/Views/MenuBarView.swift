import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var showingErrorLog = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if showingErrorLog {
                ErrorLogView().environmentObject(store)
            } else {
                PriceHeaderView()
                Divider()
                itemList
            }
        }
        .frame(width: 500)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .task {
            // Fetch both concurrently on every popover open.
            async let r: () = store.priceService.fetchRealtime(items: store.trackedItems)
            async let h: () = store.priceService.fetchHistorical(items: store.trackedItems)
            await r
            await h
        }
        .onChange(of: store.priceService.errorLog.isEmpty) { _, isEmpty in
            if isEmpty { showingErrorLog = false }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Prices").font(.headline)
            if !store.priceService.dataSource.isEmpty {
                Text("via \(store.priceService.dataSource)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // ⚠ only visible when there are logged errors
            if !store.priceService.errorLog.isEmpty {
                Button {
                    showingErrorLog.toggle()
                } label: {
                    Image(systemName: showingErrorLog
                          ? "exclamationmark.triangle.fill"
                          : "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Show error log")
            }

            Button {
                Task { await store.priceService.fetchRealtime(items: store.trackedItems) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
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
                        && store.priceService.historical[item.symbol] != nil
                )
                if item.id != store.trackedItems.last?.id {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
    }
}
