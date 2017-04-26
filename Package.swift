// swift-tools-version:3.1

import PackageDescription

let package = Package(
  name: "ReactorKit",
  dependencies: [
    .Package(url: "https://github.com/devxoul/RxSwift.git", majorVersion: 3),
    .Package(url: "https://github.com/devxoul/RxExpect.git", majorVersion: 0),
  ]
)
