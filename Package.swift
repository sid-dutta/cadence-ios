// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CadenceKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CadenceCore", targets: ["CadenceCore"]),
        .library(name: "CadenceUI", targets: ["CadenceUI"]),
    ],
    targets: [
        .target(name: "CadenceCore"),
        .target(name: "CadenceUI", dependencies: ["CadenceCore"]),
        .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"]),
    ],
    swiftLanguageModes: [.v6]
)
