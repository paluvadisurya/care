// swift-tools-version: 6.2
// Care. One Swift package, seven modules. Each module is a separate compilation
// unit with explicit dependencies, so a new feature can live in its own target
// without touching the app. See docs/ARCHITECTURE.md.

import PackageDescription

let uiSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("ExistentialAny"),
]

let pureSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "CarePackages",
    defaultLocalization: "en",
    platforms: [
        .iOS("27.0"),
        .macOS("15.0"),   // lets pure targets build in `swift build` on a Mac without Xcode UI
    ],
    products: [
        .library(name: "CareCore", targets: ["CareCore"]),
        .library(name: "CareIntelligence", targets: ["CareIntelligence"]),
        .library(name: "CareReminders", targets: ["CareReminders"]),
        .library(name: "CareDesign", targets: ["CareDesign"]),
        .library(name: "CareData", targets: ["CareData"]),
        .library(name: "CareModules", targets: ["CareModules"]),
        .library(name: "CareFixtures", targets: ["CareFixtures"]),
    ],
    targets: [
        // MARK: Pure Swift. Builds on Linux, macOS and iOS. No SwiftUI, no SwiftData.
        .target(
            name: "CareCore",
            swiftSettings: pureSettings
        ),
        .target(
            name: "CareIntelligence",
            dependencies: ["CareCore"],
            swiftSettings: pureSettings
        ),
        .target(
            name: "CareReminders",
            dependencies: ["CareCore", "CareIntelligence"],
            swiftSettings: pureSettings
        ),
        .target(
            name: "CareFixtures",
            dependencies: ["CareCore"],
            swiftSettings: pureSettings
        ),

        // MARK: Apple platforms only.
        .target(
            name: "CareDesign",
            dependencies: ["CareCore"],
            resources: [.process("Resources")],
            swiftSettings: uiSettings
        ),
        .target(
            name: "CareData",
            dependencies: ["CareCore", "CareIntelligence", "CareFixtures"],
            swiftSettings: uiSettings
        ),
        .target(
            name: "CareModules",
            dependencies: ["CareCore", "CareDesign", "CareIntelligence", "CareData"],
            swiftSettings: uiSettings
        ),

        // MARK: Tests (Swift Testing). Pure targets only, so they run anywhere.
        .testTarget(
            name: "CareCoreTests",
            dependencies: ["CareCore", "CareFixtures"],
            swiftSettings: pureSettings
        ),
        .testTarget(
            name: "CareIntelligenceTests",
            dependencies: ["CareIntelligence", "CareFixtures"],
            swiftSettings: pureSettings
        ),
        .testTarget(
            name: "CareRemindersTests",
            dependencies: ["CareReminders", "CareFixtures"],
            swiftSettings: pureSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
