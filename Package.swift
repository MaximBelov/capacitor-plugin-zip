// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorPluginZip",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapacitorPluginZip",
            targets: ["ZipPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(
            name: "ZipPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "ios/Sources/ZipPlugin"),
        .testTarget(
            name: "ZipPluginTests",
            dependencies: ["ZipPlugin"],
            path: "ios/Tests/ZipPluginTests")
    ]
)
