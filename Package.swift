// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RecordCatalogKit",
    platforms: [
        .iOS(.v26),
        // Enables `swift build`/`swift test` on development hosts; the SDK's
        // product target remains iOS 26-first.
        .macOS(.v13),
    ],
    products: [
        .library(name: "RecordCatalogKit", targets: ["RecordCatalogKit"]),
    ],
    targets: [
        .target(name: "RecordCatalogKit"),
        .testTarget(name: "RecordCatalogKitTests", dependencies: ["RecordCatalogKit"]),
    ],
    swiftLanguageModes: [.v6]
)
