// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoSidecar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "auto-sidecar",
            targets: ["AutoSidecar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AutoSidecar",
            dependencies: [],
            path: "Sources"
        )
    ]
)

