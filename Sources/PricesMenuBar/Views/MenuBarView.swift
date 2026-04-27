import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            PriceHeaderView()
            Divider()
            itemList
            if let err = store.priceService.lastError {
                Divider()
                errorBanner(err)
            }
        }
        .frame(width: 500)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store)
        }
    }

    // MARK: - Sub-views

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Prices")
                .font(.headline)
            if !store.priceService.dataSource.isEmpty {
                Text("via \(store.priceService.dataSource)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.priceService.isLoading {
                ProgressView().scaleEffect(0.55).frame(width: 16, height: 16)
            }
            Button {
                Task { await store.priceService.refresh(items: store.trackedItems) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh now")

            Button { showSettings = true } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var itemList: some View {
        if store.trackedItems.isEmpty {
            Text("No items tracked — open Settings to add some.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ForEach(store.trackedItems) { item in
                PriceRowView(item: item, data: store.priceService.prices[item.symbol])
                if item.id != store.trackedItems.last?.id {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
