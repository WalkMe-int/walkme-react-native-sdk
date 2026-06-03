// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RNWalkMeSdk",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "RNWalkMeSdkWalkMe",       targets: ["RNWalkMeSdkWalkMe"]),
        .library(name: "RNWalkMeSdkWalkMeEditor", targets: ["RNWalkMeSdkWalkMeEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/WalkMe-int/walkme-ios-sdk",        from: "1.0.0"),
        .package(url: "https://github.com/WalkMe-int/walkme-ios-sdk-editor", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RNWalkMeSdkWalkMe",
            dependencies: [
                .product(name: "WalkMe", package: "walkme-ios-sdk"),
            ],
            path: "ios/Sources/WalkMe",
            publicHeadersPath: "."
        ),
        .target(
            name: "RNWalkMeSdkWalkMeEditor",
            dependencies: [
                .product(name: "WalkMe",       package: "walkme-ios-sdk"),
                .product(name: "WalkMeEditor", package: "walkme-ios-sdk-editor"),
            ],
            path: "ios/Sources/WalkMeEditor",
            publicHeadersPath: "."
        ),
    ]
)
