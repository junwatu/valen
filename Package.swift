// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Valen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "valen", targets: ["Valen"])
    ],
    targets: [
        .systemLibrary(
            name: "CMpv",
            pkgConfig: "mpv",
            providers: [
                .brew(["mpv"])
            ]
        ),
        .executableTarget(
            name: "Valen",
            dependencies: ["CMpv"],
            path: "Sources/mpvdesk",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("OpenGL"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
