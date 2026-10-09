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
            url: "https://sdk.dev.pmcdn1.com/ios/previews/ffed40d538d495adfa45214cba3610f4afd38e0f-37886596638-1/PermateAttributionSDK-3.2.0.xcframework.zip",
            checksum: "67cd571568b79c7f64f075fa099669dfe7d97a06e1998e08ca315c07c02ac64e"
        ),
    ]
)
