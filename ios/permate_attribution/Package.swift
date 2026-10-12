// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "permate_attribution",
    platforms: [
        .iOS("13.0")
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
            url: "https://sdk.dev.pmcdn1.com/ios/previews/791eb6a85a49cb223ee3b318f4bf49ed681684c5-38278030534-1/PermateAttributionSDK-3.2.0.xcframework.zip",
            checksum: "7c656ad209a681777c81bff69f74c4a4be299330b9664cf9959b6cfbda62e93c"
        ),
    ]
)
