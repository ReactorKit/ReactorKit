// swift-tools-version:6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "ReactorKit",
  platforms: [
    .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
  ],
  products: [
    .library(name: "ReactorKit", targets: ["ReactorKit"]),
    .library(name: "ReactorKitObservation", targets: ["ReactorKitObservation"]),
    .library(name: "ReactorKitSwiftUI", targets: ["ReactorKitSwiftUI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0")),
    .package(url: "https://github.com/ReactorKit/WeakMapTable.git", .upToNextMajor(from: "1.1.0")),
    // Lower bound 510 required: ObservableStateMacro uses
    // `VariableDeclSyntax.bindingSpecifier`, renamed from `bindingKeyword` in 510.
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "510.0.0"..<"605.0.0"),
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
    .target(
      name: "ReactorKitSwiftUI",
      dependencies: [
        "ReactorKit",
        "ReactorKitObservation",
        "RxSwift",
      ]
    ),
    .target(
      name: "ReactorKitObservation",
      dependencies: [
        "ReactorKitMacros"
      ]
    ),
    .macro(
      name: "ReactorKitMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "ReactorKitTests",
      dependencies: [
        "ReactorKit",
        .product(name: "RxTest", package: "RxSwift"),
      ]
    ),
    .testTarget(
      name: "ReactorKitSwiftUITests",
      dependencies: [
        "ReactorKitSwiftUI",
        "ReactorKit",
        "ReactorKitObservation",
        .product(name: "RxTest", package: "RxSwift"),
      ]
    ),
    .testTarget(
      name: "ReactorKitMacroTests",
      dependencies: [
        "ReactorKitMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "ReactorKitObservationTests",
      dependencies: [
        "ReactorKitObservation",
      ]
    ),
  ],
)
