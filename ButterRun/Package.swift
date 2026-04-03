// swift-tools-version: 5.9
// This is provided for reference. Open the ButterRun folder in Xcode
// and create a new iOS App project, then add all files from ButterRun/.
// Alternatively, use "File > New > Project > iOS App" in Xcode with:
//   - Product Name: ButterRun
//   - Interface: SwiftUI
//   - Storage: SwiftData
//   - Minimum Deployment: iOS 17.0

import PackageDescription

let package = Package(
    name: "ButterRun",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "ButterRun",
            path: "ButterRun"
        ),
    ]
)
