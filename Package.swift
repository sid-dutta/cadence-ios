// swift-tools-version: 6.0
import PackageDescription

// Cadence is split into two library targets so that the business logic
// (CadenceCore) has zero UI dependencies and can be unit-tested on any
// platform, while CadenceUI holds every SwiftUI view. The iOS app target
// in Cadence.xcodeproj is a thin shell that links CadenceUI.
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
