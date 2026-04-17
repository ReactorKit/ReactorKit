//
//  BackportRegistrar.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

/// Observation registrar for iOS 16 and below.
/// Tracks property access via thread-local storage and notifies observers on mutation.
struct BackportRegistrar: @unchecked Sendable {

  private let extent: Extent

  init() {
    extent = Extent()
  }

  /// Records a property access into the current tracking scope (if any).
  func access<Subject: AnyObject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    guard let pointer = _ThreadLocal.value?.assumingMemoryBound(to: _AccessList?.self) else {
      return
    }
    if pointer.pointee == nil {
      pointer.pointee = _AccessList()
    }
    pointer.pointee?.addAccess(keyPath: keyPath, context: extent.context)
  }

  /// Notifies registered observers that a property is about to change.
  func willSet<Subject: AnyObject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    extent.context.willSet(keyPath)
  }

  /// Brackets a mutation with a willSet notification.
  func withMutation<Subject: AnyObject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    willSet(subject, keyPath: keyPath)
    return try mutation()
  }

  /// Records a property access using a raw AnyKeyPath.
  /// Used for per-property tracking with ObservableState.
  func accessAnyKeyPath(_ keyPath: AnyKeyPath) {
    guard let pointer = _ThreadLocal.value?.assumingMemoryBound(to: _AccessList?.self) else {
      return
    }
    if pointer.pointee == nil {
      pointer.pointee = _AccessList()
    }
    pointer.pointee?.addAccess(keyPath: keyPath, context: extent.context)
  }

  /// Notifies registered observers using a raw AnyKeyPath.
  /// Used for per-property tracking with ObservableState.
  func willSetAnyKeyPath(_ keyPath: AnyKeyPath) {
    extent.context.willSet(keyPath)
  }
}

// MARK: - Extent & Context

extension BackportRegistrar {

  private final class Extent: @unchecked Sendable {
    let context: Context
    init() {
      context = Context()
    }
  }

  final class Context: @unchecked Sendable {
    let id: ObjectIdentifier
    private let state: _ManagedCriticalState<State>

    struct State {
      var nextID = 0
      var observers = [Int: @Sendable (AnyKeyPath) -> Void]()
      var lookups = [AnyKeyPath: Set<Int>]()
    }

    init() {
      state = _ManagedCriticalState(State())
      id = ObjectIdentifier(state as AnyObject)
    }

    func register(
      for keyPaths: Set<AnyKeyPath>,
      onChange: @escaping @Sendable (AnyKeyPath) -> Void,
    ) -> Int {
      state.withCriticalRegion { state in
        let id = state.nextID
        state.nextID += 1
        state.observers[id] = onChange
        for keyPath in keyPaths {
          state.lookups[keyPath, default: []].insert(id)
        }
        return id
      }
    }

    func cancel(_ id: Int) {
      state.withCriticalRegion { state in
        state.observers.removeValue(forKey: id)
        for keyPath in state.lookups.keys {
          state.lookups[keyPath]?.remove(id)
        }
      }
    }

    func willSet(_ keyPath: AnyKeyPath) {
      let callbacks: [@Sendable (AnyKeyPath) -> Void] = state.withCriticalRegion { state in
        guard let ids = state.lookups.removeValue(forKey: keyPath) else {
          return []
        }
        var result = [@Sendable (AnyKeyPath) -> Void]()
        for id in ids {
          if let callback = state.observers.removeValue(forKey: id) {
            result.append(callback)
          }
        }
        // Clean up remaining lookups for these observer IDs
        for id in ids {
          for key in state.lookups.keys {
            state.lookups[key]?.remove(id)
          }
        }
        return result
      }
      for callback in callbacks {
        callback(keyPath)
      }
    }
  }
}
