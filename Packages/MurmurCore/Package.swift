// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MurmurCore",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "NoteStore", targets: ["NoteStore"]),
        .library(name: "SpeechEngine", targets: ["SpeechEngine"]),
        .library(name: "PersonalDictionary", targets: ["PersonalDictionary"]),
        .library(name: "TextInjection", targets: ["TextInjection"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        ),
        .target(
            name: "NoteStore",
            dependencies: ["Models"],
            path: "Sources/NoteStore"
        ),
        .target(
            name: "SpeechEngine",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Sources/SpeechEngine"
        ),
        .target(
            name: "PersonalDictionary",
            dependencies: ["Models"],
            path: "Sources/PersonalDictionary"
        ),
        .target(
            name: "TextInjection",
            dependencies: [],
            path: "Sources/TextInjection"
        ),
        .testTarget(
            name: "MurmurCoreTests",
            dependencies: ["Models", "NoteStore", "SpeechEngine", "PersonalDictionary", "TextInjection"],
            path: "Tests/MurmurCoreTests"
        ),
    ]
)
