// swift-tools-version:3.1

import Foundation
import PackageDescription

var dependencies: [Package.Dependency] = [
  .Package(url: "https://github.com/ReactiveX/RxSwift.git", majorVersion: 3),
]

let isTest = ProcessInfo.processInfo.environment["TEST"] == "1"
if isTest {
  dependencies.append(
    .Package(url: "https://github.com/devxoul/RxExpect.git", majorVersion: 0)
  )
}

let package = Package(
  name: "ReactorKit",
  dependencies: dependencies
)
