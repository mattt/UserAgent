// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UserAgent",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "UserAgent",
            targets: ["UserAgent"]
        ),
        .plugin(
            name: "UpdateBrowserDataPlugin",
            targets: ["UpdateBrowserDataPlugin"]
        ),
    ],
    targets: [
        .target(
            name: "UserAgent",
            path: "Sources/UserAgent",
            resources: [
                .copy("Resources/browsers.jsonl.lzfse")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: nil
        ),
        .plugin(
            name: "UpdateBrowserDataPlugin",
            capability: .command(
                intent: .custom(
                    verb: "update-browser-data",
                    description: "Download and update browser user agent data"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Updates browser data resource file"),
                    .allowNetworkConnections(
                        scope: .all(ports: []),
                        reason: "Downloads browser data from GitHub"
                    ),
                ]
            )
        ),
        .testTarget(
            name: "UserAgentTests",
            dependencies: ["UserAgent"]
        ),
    ]
)
