// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "permate_attribution",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "permate-attribution", targets: ["permate_attribution"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "permate_attribution",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .target(name: "PermateAttributionSDK"),
            ]
        ),
        .binaryTarget(
            name: "PermateAttributionSDK",
            url: "https://sdk.dev.pmcdn1.com/ios/previews/7a8c94fe8a858cedc00b63d584bc2198077a1d0e-38845304654-1/PermateAttributionSDK-3.2.0.xcframework.zip",
            checksum: "b204fd9ddf16285d98656055ead9b3f1214f14277fca5a6b93b6b8a651b424a3"
        ),
    ]
)
