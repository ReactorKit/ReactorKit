Pod::Spec.new do |s|
  s.name             = "ReactorKit"
  s.version          = "1.2.1"
  s.summary          = "A framework for reactive and unidirectional Swift application architecture"
  s.homepage         = "https://github.com/ReactorKit/ReactorKit"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Suyeol Jeon" => "devxoul@gmail.com" }
  s.source           = { :git => "https://github.com/ReactorKit/ReactorKit.git",
                         :tag => s.version.to_s }
  s.source_files = "Sources/**/*.{swift,h,m}"
  s.frameworks   = "Foundation"
  s.dependency "RxSwift", ">= 4.0.0"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.11"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
end
