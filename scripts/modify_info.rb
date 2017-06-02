module Pod
  class OS
    attr_accessor :deployment_target
  end

  class Spec
    attr_accessor :version
    attr_accessor :ios
    attr_accessor :osx
    attr_accessor :tvos
    attr_accessor :watchos

    def initialize
      @ios = OS.new
      @osx = OS.new
      @tvos = OS.new
      @watchos = OS.new
      yield self if block_given?
    end

    def method_missing(*args)
    end
  end
end

podspec_path = "ReactorKit.podspec"
podspec = open(podspec_path).read
spec = eval podspec

version = spec.version
ios_version = spec.ios.deployment_target
macos_version = spec.osx.deployment_target
tvos_version = spec.tvos.deployment_target
watchos_version = spec.watchos.deployment_target

def run(command)
  puts command
  `#{command} 2>&1`.strip
end

def plistbuddy(info, command)
  "PlistBuddy -c \"#{command}\" #{info}"
end

def plist_set(info, key, value)
  r = run plistbuddy(info, "Set #{key} #{value}")
  if r.include? "Not Exist"
    run plistbuddy(info, "Add #{key} string #{value}")
  end
end

if ios_version
  info = "./Carthage/Build/iOS/ReactorKit.framework/Info.plist"
  plist_set(info, "CFBundleVersion", version)
end

if macos_version
  info = "./Carthage/Build/Mac/ReactorKit.framework/Resources/Info.plist"
  plist_set(info, "CFBundleVersion", version)
end

if tvos_version
  info = "./Carthage/Build/tvOS/ReactorKit.framework/Info.plist"
  plist_set(info, "CFBundleVersion", version)
end

if watchos_version
  info = "./Carthage/Build/watchOS/ReactorKit.framework/Info.plist"
  plist_set(info, "CFBundleVersion", version)
end
