// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyWii",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Global hotkey registration (thin wrapper over Carbon RegisterEventHotKey)
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "KeyWii",
            dependencies: ["HotKey"],
            path: "Sources/KeyWii"
        )
    ]
)
