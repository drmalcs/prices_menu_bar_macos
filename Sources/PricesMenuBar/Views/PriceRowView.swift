import SwiftUI

private enum Col {
    static let name:   CGFloat = 96
    static let price:  CGFloat = 100
    static let change: CGFloat = 60
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
    let isStale: Bool           // realtime loading + old data exists → grey price/1h/val
    let isHistoricalStale: Bool // historical loading + old data exists → grey 24h/1y

    var body: some View {
        HStack(spacing: 0) {
            Text(item.displayName)
                .frame(width: Col.name, alignment: .leading)
            priceCell
            oneHourCell
            historicalPercentCell(referencePrice: historical?.previousClose)
            historicalPercentCell(referencePrice: historical?.yearAgoClose)
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
    private var oneHourCell: some View {
        if let rt = realtime {
            switch rt.marketState {
            case .closed:
                Text("CLOSED")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: Col.change, alignment: .trailing)
            case .openLessThan1h:
                if let v = rt.change1h {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(formatChangeNoPct(v))
                            .foregroundStyle(isStale ? Color.secondary : Color.primary)
                        Text("%")
                            .foregroundStyle(isStale ? Color.secondary : Theme.warning)
                    }
                    .frame(width: Col.change)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                        .frame(width: Col.change, alignment: .trailing)
                }
            case .open:
                if let v = rt.change1h {
                    Text(formatChange(v))
                        .foregroundStyle(isStale ? Color.secondary : changeColor(v))
                        .frame(width: Col.change, alignment: .trailing)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                        .frame(width: Col.change, alignment: .trailing)
                }
            }
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.change, alignment: .trailing)
        }
    }

    // Used for both 24h and 1y columns.
    // Requires both a live price (realtime) and a reference price (historical).
    // Grey when either is being refreshed.
    @ViewBuilder
    private func historicalPercentCell(referencePrice: Double?) -> some View {
        if let rt = realtime, let ref = referencePrice, ref > 0 {
            let pct = (rt.priceUSD - ref) / ref * 100
            let isRefreshing = isStale || isHistoricalStale
            Text(formatChange(pct))
                .foregroundStyle(isRefreshing ? Color.secondary : changeColor(pct))
                .frame(width: Col.change, alignment: .trailing)
        } else {
            Text("—").foregroundStyle(.tertiary)
                .frame(width: Col.change, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var valCell: some View {
        if let rt = realtime, item.quantity > 0 {
            Text(formatGBP(rt.priceGBP * item.quantity * (1 - item.taxRate / 100)))
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
        return c >= 0 ? Theme.positive : Theme.negative
    }

    private func changeColor(_ v: Double) -> Color {
        v >= 0 ? Theme.positive : Theme.negative
    }

    private func formatUSD(_ v: Double) -> String {
        let decimals: Int
        if v >= 10_000    { decimals = 0 }
        else if v >= 1    { decimals = 2 }
        else if v >= 0.01 { decimals = 4 }
        else              { decimals = 6 }
        return "$" + Self.numFmt(v, decimals: decimals)
    }

    private func formatGBP(_ v: Double) -> String {
        "£" + Self.numFmt(v, decimals: v >= 1_000 ? 0 : 2)
    }

    private func formatChange(_ v: Double) -> String {
        String(format: "%@%.1f%%", v >= 0 ? "+" : "", v)
    }

    private func formatChangeNoPct(_ v: Double) -> String {
        String(format: "%@%.1f", v >= 0 ? "+" : "", v)
    }

    private static let numFmtCache: [Int: NumberFormatter] = {
        var cache: [Int: NumberFormatter] = [:]
        for d in 0...6 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.usesGroupingSeparator = true
            f.minimumFractionDigits = d
            f.maximumFractionDigits = d
            cache[d] = f
        }
        return cache
    }()

    private static func numFmt(_ v: Double, decimals: Int) -> String {
        let f = numFmtCache[decimals] ?? {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.usesGroupingSeparator = true
            f.minimumFractionDigits = decimals
            f.maximumFractionDigits = decimals
            return f
        }()
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
