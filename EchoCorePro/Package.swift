// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EchoCorePro",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EchoCorePro", targets: ["EchoCorePro"])
    ],
    targets: [
        .executableTarget(
            name: "EchoCorePro",
            path: "Sources/EchoCorePro"
        ),
        .testTarget(
            name: "EchoCoreProTests",
            dependencies: ["EchoCorePro"],
            path: "Tests/EchoCoreProTests"
        )
    ]
)
