// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commandLineToolsFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let commandLineToolsDeveloperLibraryPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "SpeakEasyTTS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpeakEasyTTS", targets: ["SpeakEasyTTS"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpeakEasyTTS",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SpeakEasyTTSTests",
            dependencies: ["SpeakEasyTTS"],
            path: "Tests/SpeakEasyTTSTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-F", commandLineToolsFrameworksPath])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", commandLineToolsFrameworksPath,
                    "-Xlinker", "-rpath",
                    "-Xlinker", commandLineToolsFrameworksPath,
                    "-Xlinker", "-rpath",
                    "-Xlinker", commandLineToolsDeveloperLibraryPath
                ])
            ]
        )
    ]
)
