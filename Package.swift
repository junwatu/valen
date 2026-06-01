// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Valen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "valen", targets: ["Valen"]),
        .executable(name: "valen-mcp", targets: ["valen-mcp"])
    ],
    targets: [
        .systemLibrary(
            name: "CMpv",
            path: "Packaging/Sources/CMpv",
            pkgConfig: "mpv",
            providers: [
                .brew(["mpv"])
            ]
        ),
        .target(
            name: "ValenControl",
            path: "Packaging/Sources/ValenControl"
        ),
        .executableTarget(
            name: "Valen",
            dependencies: ["CMpv", "ValenControl"],
            path: "Packaging/Sources/mpvdesk",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("OpenGL"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "valen-mcp",
            dependencies: ["ValenControl"],
            path: "Packaging/Sources/valen-mcp"
        ),
        .testTarget(
            name: "ValenTests",
            dependencies: ["Valen", "ValenControl"],
            path: "Tests/ValenTests"
        )
    ]
)

