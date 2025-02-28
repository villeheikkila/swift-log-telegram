// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "swift-log-telegram",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
    products: [
        .library(
            name: "SwiftLogTelegram",
            targets: ["SwiftLogTelegram"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.2"),
    ],
    targets: [
        .target(
            name: "SwiftLogTelegram",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "SwiftLogTelegramTests",
            dependencies: ["SwiftLogTelegram"]
        ),
    ]
)
