Pod::Spec.new do |s|
  s.name             = "ReactorKit"
  s.version          = "2.1.0"
  s.summary          = "A framework for reactive and unidirectional Swift application architecture"
  s.homepage         = "https://github.com/ReactorKit/ReactorKit"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Suyeol Jeon" => "devxoul@gmail.com" }
  s.source           = { :git => "https://github.com/ReactorKit/ReactorKit.git",
                         :tag => s.version.to_s }
  s.source_files = "Sources/**/*.{swift,h,m}"
  s.frameworks   = "Foundation"
  s.swift_version = "5.0"
  s.dependency "RxSwift", "~> 5.0"
  s.dependency "WeakMapTable", "~> 1.1"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.11"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "3.0"
end
