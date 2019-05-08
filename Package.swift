// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "ReactorKit",
  products: [
    .library(name: "ReactorKit", targets: ["ReactorKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "5.0.0")),

    // TODO: Update when RxExpect support RxSwift 5.0
    // .package(url: "https://github.com/devxoul/RxExpect.git", .upToNextMajor(from: "1.0.0"))
    .package(url: "https://github.com/tokijh/RxExpect.git", .branch("master"))
  ],
  targets: [
    .target(name: "ReactorKit", dependencies: ["ReactorKitRuntime", "RxSwift", "RxRelay"]),
    .target(name: "ReactorKitRuntime", dependencies: []),
    .testTarget(name: "ReactorKitTests", dependencies: ["ReactorKit", "RxExpect"]),
  ]
)
