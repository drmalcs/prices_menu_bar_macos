import SwiftUI

private enum Col {
    static let name:   CGFloat = 72
    static let price:  CGFloat = 100
    static let change: CGFloat = 68
    static let val:    CGFloat = 90
}

struct PriceHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Asset") .frame(width: Col.name,   alignment: .leading)
            Text("Price") .frame(width: Col.price,  alignment: .trailing)
            Text("1h")    .frame(width: Col.change, alignment: .trailing)
            Text("24h")   .frame(width: Col.change, alignment: .trailing)
            Text("1y")    .frame(width: Col.change, alignment: .trailing)
            Text("Val")   .frame(width: Col.val,    alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct PriceRowView: View {
    let item: TrackedItem
    let realtime: RealtimeData?
    let historical: HistoricalData?
    let isStale: Bool   // true while realtime is loading and old data exists

    var body: some View {
        HStack(spacing: 0) {
            Text(item.displayName)
                .frame(width: Col.name, alignment: .leading)

            // Price: coloured by 1h direction; grey when stale
            priceCell

            // 1h: grey when stale, otherwise green/red
            realtimeChangeCell(realtime?.change1h)

            // 24h and 1y: always green/red — historical data doesn't go stale
            historicalChangeCell(historical?.change24h)
            historicalChangeCell(historical?.change1y)

            // Val: grey when stale
            valCell
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Cells

    @ViewBuilder
    private var priceCell: some View {
        if let rt = realtime {
            Text(formatUSD(rt.priceUSD))
                .foregroundStyle(isStale ? Color.secondary : priceColor(rt.change1h))
                .frame(width: Col.price, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.price, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func realtimeChangeCell(_ value: Double?) -> some View {
        if let v = value {
            Text(formatChange(v))
                .foregroundStyle(isStale ? Color.secondary : (v >= 0 ? Color.green : Color.red))
                .frame(width: Col.change, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.change, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func historicalChangeCell(_ value: Double?) -> some View {
        if let v = value {
            Text(formatChange(v))
                .foregroundStyle(v >= 0 ? Color.green : Color.red)
                .frame(width: Col.change, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.change, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var valCell: some View {
        if let rt = realtime, item.quantity > 0 {
            Text(formatGBP(rt.priceGBP * item.quantity))
                .foregroundStyle(isStale ? Color.secondary : Color.primary)
                .frame(width: Col.val, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.val, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func priceColor(_ change1h: Double?) -> Color {
        guard let c = change1h else { return .primary }
        return c >= 0 ? .green : .red
    }

    private func formatUSD(_ v: Double) -> String {
        if v >= 10_000 { return String(format: "$%,.0f", v) }
        if v >= 1      { return String(format: "$%.2f", v) }
        if v >= 0.01   { return String(format: "$%.4f", v) }
        return String(format: "$%.6f", v)
    }

    private func formatGBP(_ v: Double) -> String {
        v >= 1_000 ? String(format: "£%,.0f", v) : String(format: "£%.2f", v)
    }

    private func formatChange(_ v: Double) -> String {
        String(format: "%@%.1f%%", v >= 0 ? "+" : "", v)
    }
}
