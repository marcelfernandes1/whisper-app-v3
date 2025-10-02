// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WhisperTranscribe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WhisperTranscribe",
            targets: ["WhisperTranscribe"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WhisperTranscribe",
            path: "Sources"
        )
    ]
)
