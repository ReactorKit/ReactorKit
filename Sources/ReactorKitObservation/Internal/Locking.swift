//
//  Locking.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Darwin

/// A lock-protected container that co-allocates the lock and state in a single heap allocation.
/// Based on Apple's Observation module pattern using ManagedBuffer.
struct _ManagedCriticalState<State> {

  private let buffer: ManagedBuffer<State, os_unfair_lock>

  init(_ initial: State) {
    buffer = LockedBuffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { lock in
        lock.initialize(to: os_unfair_lock())
      }
      return initial
    } as! LockedBuffer<State>
  }

  func withCriticalRegion<R>(_ critical: (inout State) throws -> R) rethrows -> R {
    try buffer.withUnsafeMutablePointers { header, lock in
      os_unfair_lock_lock(lock)
      defer { os_unfair_lock_unlock(lock) }
      return try critical(&header.pointee)
    }
  }
}

private final class LockedBuffer<State>: ManagedBuffer<State, os_unfair_lock> {
  deinit {
    withUnsafeMutablePointerToElements { _ = $0.deinitialize(count: 1) }
  }
}

extension _ManagedCriticalState: @unchecked Sendable where State: Sendable {}
