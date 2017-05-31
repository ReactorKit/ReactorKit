require "xcodeproj"

project = Xcodeproj::Project.open("ReactorKit.xcodeproj") or exit
target = project.targets.find { |t| t.name == "ReactorKit" } or exit
phase = target.build_phases.find { |p| p.kind_of?(Xcodeproj::Project::Object::PBXFrameworksBuildPhase) } or exit
file = phase.files_references.find { |f| f.path == "RxCocoaRuntime.framework" } or exit
phase.remove_file_reference(file)
project.save
