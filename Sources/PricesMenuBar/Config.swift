import Foundation

enum Config {
    // Called once at launch from AppDelegate to load .env into the process environment.
    static func loadDotEnv() {
        let candidates = [
            // Project root when running from Xcode
            FileManager.default.currentDirectoryPath + "/.env",
            // Alongside the built .app bundle
            (Bundle.main.bundlePath as NSString).deletingLastPathComponent + "/.env",
        ]
        for path in candidates {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            content.components(separatedBy: .newlines).forEach { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty, !t.hasPrefix("#") else { return }
                let parts = t.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                setenv(parts[0].trimmingCharacters(in: .whitespaces),
                       parts[1].trimmingCharacters(in: .whitespaces), 1)
            }
            return
        }
    }

    static var alphaVantageKey: String {
        // Process env wins (set by loadDotEnv or Xcode scheme); UserDefaults as a runtime fallback.
        if let key = ProcessInfo.processInfo.environment["ALPHAVANTAGE_KEY"], !key.isEmpty {
            return key
        }
        return UserDefaults.standard.string(forKey: "alphaVantageKey") ?? ""
    }

    static func setAlphaVantageKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "alphaVantageKey")
    }
}
