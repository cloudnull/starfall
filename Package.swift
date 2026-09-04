// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Starfall",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StarfallApp",
            dependencies: [
                "StarfallRender",
                "StarfallAudio",
                "StarfallInput",
                "StarfallMelee",
                "StarfallCampaign",
                "StarfallAI"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .target(
            name: "StarfallCore",
            dependencies: []
        ),
        .target(
            name: "StarfallData",
            dependencies: ["StarfallCore"]
        ),
        .target(
            name: "StarfallMelee",
            dependencies: ["StarfallCore", "StarfallData"]
        ),
        .target(
            name: "StarfallCampaign",
            dependencies: ["StarfallCore", "StarfallData", "StarfallMelee"]
        ),
        .target(
            name: "StarfallAI",
            dependencies: ["StarfallCore", "StarfallMelee", "StarfallCampaign"]
        ),
        .target(
            name: "StarfallInput",
            dependencies: ["StarfallCore"]
        ),
        .target(
            name: "StarfallRender",
            dependencies: ["StarfallCore", "StarfallMelee", "StarfallCampaign", "StarfallData", "StarfallAudio"],
            linkerSettings: [
                .linkedFramework("SpriteKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .target(
            name: "StarfallAudio",
            dependencies: ["StarfallCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation")
            ]
        ),
        .testTarget(
            name: "StarfallCoreTests",
            dependencies: ["StarfallCore"]
        ),
        .testTarget(
            name: "StarfallMeleeTests",
            dependencies: ["StarfallMelee", "StarfallData"]
        ),
        .testTarget(
            name: "StarfallAITests",
            dependencies: ["StarfallAI", "StarfallMelee", "StarfallData"]
        ),
        .testTarget(
            name: "StarfallCampaignTests",
            dependencies: ["StarfallCampaign", "StarfallData"]
        )
    ]
)