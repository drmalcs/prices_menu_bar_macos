// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PricesMenuBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "PricesMenuBar",
            path: "Sources/PricesMenuBar",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/PricesMenuBar/Resources/Info.plist"
                ])
            ]
        )
    ]
)
