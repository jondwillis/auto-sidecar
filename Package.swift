// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoSidecar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "auto-sidecar",
            targets: ["AutoSidecar"]
        ),
        .plugin(
            name: "BuildApp",
            targets: ["BuildAppPlugin"]
        ),
        .plugin(
            name: "DevTools",
            targets: ["DevToolsPlugin"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AutoSidecar",
            dependencies: [],
            path: "Sources"
        ),
        .plugin(
            name: "BuildAppPlugin",
            capability: .command(
                intent: .custom(
                    verb: "build-app",
                    description: "Build Auto Sidecar.app bundle"
                )
            )
        ),
        .plugin(
            name: "DevToolsPlugin",
            capability: .command(
                intent: .custom(
                    verb: "dev-tools",
                    description: "Development tools (validate, diagnose, status)"
                )
            )
        )
    ]
)

