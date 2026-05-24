// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SetaMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SetaMacCore", targets: ["SetaMacCore"]),
        .executable(name: "SetaMac", targets: ["SetaMacApp"]),
        .executable(name: "SetaMacChecks", targets: ["SetaMacChecks"])
    ],
    targets: [
        .target(name: "SetaMacCore"),
        .executableTarget(
            name: "SetaMacApp",
            dependencies: ["SetaMacCore"]
        ),
        .executableTarget(
            name: "SetaMacChecks",
            dependencies: ["SetaMacCore"]
        )
    ]
)
