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

        // Settings runs as its own activating window, independent of the
        // MenuBarExtra panel, so text fields receive keyboard input correctly.
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        Image(nsImage: Self.menuBarIcon)
    }

    // Renders "B" into an NSImage template so macOS automatically colours it
    // white in dark menu bars and black in light ones.
    private static let menuBarIcon: NSImage = {
        let size = CGSize(width: 22, height: 22)
        let img = NSImage(size: size, flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: 20, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
            ]
            let s = "B" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (rect.width - sz.width) / 2,
                               y: (rect.height - sz.height) / 2),
                   withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
    }()

    private static let menuBarFmtWhole: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.usesGroupingSeparator = true; f.maximumFractionDigits = 0; f.minimumFractionDigits = 0
        return f
    }()
    private static let menuBarFmtDecimal: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.usesGroupingSeparator = true; f.maximumFractionDigits = 2; f.minimumFractionDigits = 2
        return f
    }()

    private func menuBarPrice(_ v: Double) -> String {
        let f = v >= 1_000 ? Self.menuBarFmtWhole : Self.menuBarFmtDecimal
        return "$" + (f.string(from: NSNumber(value: v)) ?? String(v))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Config.loadDotEnv()
    }
}
