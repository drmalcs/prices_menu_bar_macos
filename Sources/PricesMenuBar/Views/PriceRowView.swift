import SwiftUI

// Column widths — keep in sync with PriceHeaderView.
private enum Col {
    static let name:   CGFloat = 72
    static let price:  CGFloat = 100
    static let change: CGFloat = 68
    static let val:    CGFloat = 90
}

struct PriceHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Asset")  .frame(width: Col.name,   alignment: .leading)
            Text("Price")  .frame(width: Col.price,  alignment: .trailing)
            Text("1h")     .frame(width: Col.change, alignment: .trailing)
            Text("24h")    .frame(width: Col.change, alignment: .trailing)
            Text("1y")     .frame(width: Col.change, alignment: .trailing)
            Text("Val")    .frame(width: Col.val,    alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct PriceRowView: View {
    let item: TrackedItem
    let data: PriceData?

    var body: some View {
        HStack(spacing: 0) {
            Text(item.displayName)
                .frame(width: Col.name, alignment: .leading)

            if let d = data {
                // Price colour tracks 1hr direction (green=up, red=down per spec).
                Text(formatUSD(d.priceUSD))
                    .foregroundStyle(priceColor(d.change1h))
                    .frame(width: Col.price, alignment: .trailing)

                changeCell(d.change1h)
                changeCell(d.change24h)
                changeCell(d.change1y)
                valCell(d)
            } else {
                ForEach(0..<5, id: \.self) { _ in
                    Text("—").foregroundStyle(.tertiary)
                        .frame(width: Col.change, alignment: .trailing)
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func changeCell(_ value: Double?) -> some View {
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
    private func valCell(_ d: PriceData) -> some View {
        if item.quantity > 0 {
            Text(formatGBP(d.priceGBP * item.quantity))
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
