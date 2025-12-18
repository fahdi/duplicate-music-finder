// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DuplicateMusicFinder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DuplicateMusicFinder",
            targets: ["DuplicateMusicFinder"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "DuplicateMusicFinder",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("iTunesLibrary")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
