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
            url: "https://sdk.dev.pmcdn1.com/ios/previews/5e6f3ebdf14350bc53ca852aba1dbf3c03f7ebce-38352218945-1/PermateAttributionSDK-3.2.0.xcframework.zip",
            checksum: "5ab2b0ded2ada41844c0a6b3229d5f881dd208553fcc7fdafa3896a88de5b115"
        ),
    ]
)
