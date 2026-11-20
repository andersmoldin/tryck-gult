// swift-tools-version:6.0
import PackageDescription

// Spelmodellen för Brytare-prototypen: ren Swift utan SwiftUI och utan timers,
// så att reglerna kan testas med `swift test` direkt på datorn (ingen simulator).
let package = Package(
    name: "BrytareModell",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BrytareModell", targets: ["BrytareModell"]),
    ],
    targets: [
        .target(name: "BrytareModell"),
        .testTarget(name: "BrytareModellTests", dependencies: ["BrytareModell"]),
    ]
)
