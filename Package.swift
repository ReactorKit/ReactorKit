// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "ReactorKit",
  platforms: [
    .macOS(.v10_13), .iOS(.v12), .tvOS(.v12), .watchOS(.v4),
  ],
  products: [
    .library(name: "ReactorKit", targets: ["ReactorKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0")),
    .package(url: "https://github.com/ReactorKit/WeakMapTable.git", .upToNextMajor(from: "1.1.0")),
  ],
  targets: [
    .target(
      name: "ReactorKit",
      dependencies: [
        "ReactorKitRuntime",
        "RxSwift",
        "WeakMapTable",
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
        .product(name: "RxTest", package: "RxSwift"),
      ]
    ),
  ],
  swiftLanguageModes: [.v5]
)
