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
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .binaryTarget(
            name: "PermateAttributionSDK",
            url: "https://sdk.dev.pmcdn1.com/ios/previews/bce7d8f7e36969b63205b2e868259ab9c4d942ca-37910469355-1/PermateAttributionSDK-3.2.0.xcframework.zip",
            checksum: "d2d98f4f859605e591fb9a21a507e8aea75831f598ac984753560724d1898967"
        ),
    ]
)
