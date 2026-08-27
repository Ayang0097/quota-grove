// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuotaGrove",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuotaGrove", targets: ["QuotaGrove"])
    ],
    targets: [
        .executableTarget(
            name: "QuotaGrove",
            path: "Sources/QuotaGrove"
        )
    ],
    swiftLanguageModes: [.v5]
)
