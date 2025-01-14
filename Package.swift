// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lychee",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16)
    ],
    products: [
        .library(name: "Lychee", targets: [
            "Lychee"
        ]),
        .library(name: "LycheeC", targets: [
            "LycheeC"
        ]),
        .library(name: "LycheeObjC", targets: [
            "LycheeObjC"
        ])
    ],
    dependencies: [
        .package(url: "https://github.com/ctreffs/SwiftSDL2", branch: "master")
    ],
    targets: [
        .target(name: "Lychee", dependencies: [
            "LycheeObjC"
        ]),
        .target(name: "LycheeC", sources: [
            "",
            "dev",
            "dev/cdrom",
            "frontend",
            "input"
        ], publicHeadersPath: "include", cSettings: [
            .unsafeFlags([
                "-g"
            ])
        ], cxxSettings: [
            .unsafeFlags([
                "-Ofast -Wno-overflow -Wall -pedantic -Wno-address-of-packed-member -flto"
            ])
        ]),
        .target(name: "LycheeObjC", dependencies: [
            "LycheeC",
            .product(name: "SDL", package: "SwiftSDL2")
        ], publicHeadersPath: "include")
    ],
    cLanguageStandard: .c2x,
    cxxLanguageStandard: .cxx2b
)
