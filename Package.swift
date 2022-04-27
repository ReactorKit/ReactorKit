// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "ReactorKit",
  platforms: [
    .macOS(.v10_11), .iOS(.v9), .tvOS(.v9), .watchOS(.v3)
  ],
  products: [
    .library(name: "ReactorKit", targets: ["ReactorKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0")),
    .package(url: "https://github.com/ReactorKit/WeakMapTable.git", .upToNextMajor(from: "1.1.0"))
  ],
  targets: [
    .target(
      name: "ReactorKit",
      dependencies: [
        "ReactorKitRuntime",
        "RxSwift",
        "WeakMapTable"
      ]
    ),
    .target(
      name: "ReactorKitRuntime",
      dependencies: []
    ),
    .testTarget(
      name: "ReactorKitTests",
      dependencies: [
        "ReactorKit",
        .product(name: "RxTest", package: "RxSwift")
      ]
    ),
  ],
  swiftLanguageVersions: [.v5]
)
