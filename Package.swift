// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AllDoc",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AllDoc",
            path: "Sources/AllDoc",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
