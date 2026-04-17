Pod::Spec.new do |s|
  s.name             = "ReactorKit"
  s.version          = "3.2.0"
  s.summary          = "A framework for reactive and unidirectional Swift application architecture"
  s.homepage         = "https://github.com/ReactorKit/ReactorKit"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Suyeol Jeon" => "devxoul@gmail.com" }
  s.source           = { :git => "https://github.com/ReactorKit/ReactorKit.git",
                         :tag => s.version.to_s }
  s.swift_version = "6.0"

  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "10.15"
  s.tvos.deployment_target = "13.0"
  s.watchos.deployment_target = "6.0"

  s.source_files = "Sources/ReactorKit/**/*.{swift,h,m}",
                    "Sources/ReactorKitRuntime/**/*.{swift,h,m}"
  s.frameworks   = "Foundation"
  s.dependency "RxSwift", "~> 6.0"
  s.dependency "WeakMapTable", "~> 1.1"

  # NOTE: ReactorKitSwiftUI / ReactorKitObservation are SPM-only.
  # They depend on Swift macros which CocoaPods does not support.
  # Use Swift Package Manager for SwiftUI integration:
  #   .product(name: "ReactorKitSwiftUI", package: "ReactorKit")
end
