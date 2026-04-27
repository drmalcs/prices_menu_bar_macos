// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PricesMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PricesMenuBar",
            path: "Sources/PricesMenuBar"
        )
    ]
)
