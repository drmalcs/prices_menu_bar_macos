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

    // Shows the first tracked item's current price, or a fallback icon.
    @ViewBuilder
    private var menuBarLabel: some View {
        if let first = store.trackedItems.first,
           let price = store.priceService.prices[first.symbol] {
            Text(menuBarPrice(price.priceUSD))
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
        // Hide from Dock — this is a menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)
        // Load API keys from .env file if present.
        Config.loadDotEnv()
    }
}
