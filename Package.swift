// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CodexPet",
            targets: ["CodexPetApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexPetApp"
        )
    ]
)
