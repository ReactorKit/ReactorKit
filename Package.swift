// swift-tools-version:4.2

import PackageDescription

let package = Package(
  name: "ReactorKit",
  products: [
    .library(name: "ReactorKit", targets: ["ReactorKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "4.0.0")),
    .package(url: "https://github.com/devxoul/RxExpect.git", .upToNextMajor(from: "1.0.0"))
  ],
  targets: [
    .target(name: "ReactorKit", dependencies: ["ReactorKitRuntime", "RxSwift"]),
    .target(name: "ReactorKitRuntime", dependencies: []),
    .testTarget(name: "ReactorKitTests", dependencies: ["ReactorKit", "RxExpect"]),
  ]
)
