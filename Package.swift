// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glint",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Glint", targets: ["Glint"])],
    targets: [
        .executableTarget(name: "Glint", path: "Sources"),
        .testTarget(name: "GlintTests", dependencies: ["Glint"], path: "Tests")
    ]
)
