// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tassel",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Global hotkey registration (thin wrapper over Carbon RegisterEventHotKey)
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "Tassel",
            dependencies: ["HotKey"],
            path: "Sources/Tassel"
        )
    ]
)
