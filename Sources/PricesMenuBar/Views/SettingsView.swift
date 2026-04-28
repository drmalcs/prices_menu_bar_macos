import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var query = ""
    @State private var results: [YahooSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    addSection
                    Divider()
                    trackedSection
                    Divider()
                    legendSection
                    Divider()
                    apiKeySection
                }
                .padding()
            }
        }
        .frame(width: 420, height: 540)
    }

    // MARK: - Sections

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Item").font(.subheadline).bold()
            Text("Enter a Yahoo Finance ticker: BTC-USD, AAPL, LLOY.L, ETH-USD…")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                TextField("Search ticker or name", text: $query)
                    .onSubmit { runSearch() }
                Button("Search") { runSearch() }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            if let err = searchError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            ForEach(results) { result in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.symbol).bold()
                        Text(result.displayLabel).font(.caption).foregroundStyle(.secondary)
                        if let exch = result.exchDisp {
                            Text(exch).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button("Add") { add(result) }
                        .disabled(store.trackedItems.contains { $0.symbol == result.symbol })
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var trackedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracked Items").font(.subheadline).bold()
            Text("Set Qty and Tax % to calculate the Val (GBP) column. Val = price × qty × (1 − tax).")
                .font(.caption).foregroundStyle(.secondary)

            ForEach($store.trackedItems) { $item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName).bold()
                        Text(item.symbol).font(.caption).foregroundStyle(.secondary)
                        Text(item.assetType.rawValue).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Qty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", value: $item.quantity, format: .number)
                            .frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Text("Tax %")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", value: $item.taxRate, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                    Button(role: .destructive) {
                        store.trackedItems.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private var legendSection: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("1h")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("%")
                .font(.caption)
                .foregroundStyle(Theme.warning)
            Text(" — When yellow, the market has been open less than 1 hour. The figure compares the current price to the previous session's close, not a true 60-minute move.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alpha Vantage API Key").font(.subheadline).bold()
            Text("Used as a fallback when Yahoo Finance throttles. Leave blank to use Yahoo only.")
                .font(.caption).foregroundStyle(.secondary)

            SecureAPIKeyField()
        }
    }

    // MARK: - Actions

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        searchError = nil
        results = []
        Task {
            do {
                results = try await YahooSearchService().search(query: q)
                if results.isEmpty { searchError = "No results for \"\(q)\"" }
            } catch {
                searchError = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func add(_ result: YahooSearchResult) {
        let item = TrackedItem(
            symbol: result.symbol,
            displayName: result.shortname ?? result.symbol,
            assetType: result.inferredAssetType,
            quantity: 0
        )
        store.trackedItems.append(item)
        results = []
        query = ""
    }
}

// Separate view to avoid binding the SecureField to a computed property.
private struct SecureAPIKeyField: View {
    @State private var key: String = Config.alphaVantageKey
    @State private var saved = false

    var body: some View {
        HStack {
            SecureField("Paste key here", text: $key)
                .textFieldStyle(.roundedBorder)
            Button(saved ? "Saved" : "Save") {
                Config.setAlphaVantageKey(key)
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
            }
            .disabled(key == Config.alphaVantageKey)
        }
    }
}
