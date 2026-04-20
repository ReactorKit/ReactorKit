//
//  RuntimeWarning.swift
//  ReactorKit
//
//  Created by Kanghoon Oh on 4/20/26.
//

#if DEBUG
import os.log

private let _log = OSLog(subsystem: "com.reactorkit", category: "Reactor")

/// Emits a runtime warning visible in Xcode's console as a fault-level os_log.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
func _runtimeWarning(_ message: @autoclosure () -> String) {
  os_log(.fault, log: _log, "%{public}@", message())
}
#endif
