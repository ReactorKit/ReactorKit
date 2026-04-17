//
//  ObservationTracking.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Foundation

/// Executes `apply`, records all BackportRegistrar.access() calls made during execution,
/// then installs a one-shot observer that calls `onChange` when any tracked property changes.
public func _withStateTracking<T>(
  _ apply: () -> T,
  onChange: @escaping @Sendable () -> Void
) -> T {
  let (result, accessList) = _generateAccessList(apply)
  if let accessList {
    accessList.installTracking(onChange: onChange)
  }
  return result
}

// MARK: - _AccessList

/// Collects property accesses recorded during a `withStateTracking` scope.
struct _AccessList: Sendable {

  struct Entry: @unchecked Sendable {
    var context: BackportRegistrar.Context
    var keyPaths: Set<AnyKeyPath>
  }

  var entries = [ObjectIdentifier: Entry]()

  mutating func addAccess(
    keyPath: AnyKeyPath,
    context: BackportRegistrar.Context
  ) {
    entries[context.id, default: Entry(context: context, keyPaths: [])].keyPaths.insert(keyPath)
  }

  mutating func merge(_ other: _AccessList) {
    for (id, otherEntry) in other.entries {
      if var existing = entries[id] {
        existing.keyPaths.formUnion(otherEntry.keyPaths)
        entries[id] = existing
      } else {
        entries[id] = otherEntry
      }
    }
  }

  func installTracking(onChange: @escaping @Sendable () -> Void) {
    guard !entries.isEmpty else { return }

    // Register all observers first, then install the registration map
    // atomically. A `willSet` that fires during Phase 1 will flip `fired`,
    // and Phase 2 cancels every registered observer to prevent leaks.
    let shared = _ManagedCriticalState(_TrackingState())

    // Phase 1: register observers. Callbacks may fire concurrently.
    var registered = [(BackportRegistrar.Context, Int)]()
    for (_, entry) in entries {
      let id = entry.context.register(for: entry.keyPaths) { [shared] _ in
        let shouldFire: Bool = shared.withCriticalRegion { state in
          if state.fired { return false }
          state.fired = true
          return true
        }
        guard shouldFire else { return }

        let regs = shared.withCriticalRegion { $0.registrations }
        for (ctx, regID) in regs {
          ctx.cancel(regID)
        }

        onChange()
      }
      registered.append((entry.context, id))
    }

    // Phase 2: atomic install. If a willSet already fired during Phase 1,
    // cancel every observer here so none leak past the one-shot boundary.
    let alreadyFired = shared.withCriticalRegion { state -> Bool in
      if state.fired { return true }
      state.registrations = registered
      return false
    }
    if alreadyFired {
      for (ctx, id) in registered {
        ctx.cancel(id)
      }
    }
  }
}

// MARK: - Private helpers

private func _generateAccessList<T>(_ apply: () -> T) -> (T, _AccessList?) {
  var accessList: _AccessList?
  let result: T = withUnsafeMutablePointer(to: &accessList) { pointer in
    let previous = _ThreadLocal.value
    _ThreadLocal.value = UnsafeMutableRawPointer(pointer)
    defer {
      if let previous {
        // Nested: merge our access list into the parent.
        if let inner = pointer.pointee {
          let parentPointer = previous.assumingMemoryBound(to: _AccessList?.self)
          if parentPointer.pointee == nil {
            parentPointer.pointee = _AccessList()
          }
          parentPointer.pointee?.merge(inner)
        }
      }
      _ThreadLocal.value = previous
    }
    return apply()
  }
  return (result, accessList)
}

private struct _TrackingState: @unchecked Sendable {
  var fired = false
  var registrations = [(BackportRegistrar.Context, Int)]()
}
