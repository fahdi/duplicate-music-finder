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
    dependencies: [
        .package(url: "https://github.com/chicio/ID3TagEditor.git", from: "4.6.0")
    ],
    targets: [
        .executableTarget(
            name: "DuplicateMusicFinder",
            dependencies: ["ID3TagEditor"],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("iTunesLibrary")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
