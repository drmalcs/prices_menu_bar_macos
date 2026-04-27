import SwiftUI
import AppKit

@main
struct PricesMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if let first = store.trackedItems.first,
           let rt = store.priceService.realtime[first.symbol] {
            Text(menuBarPrice(rt.priceUSD))
                .font(.system(.body, design: .monospaced))
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
    }

    private func menuBarPrice(_ v: Double) -> String {
        v >= 1_000 ? String(format: "$%,.0f", v) : String(format: "$%.2f", v)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Config.loadDotEnv()
    }
}
