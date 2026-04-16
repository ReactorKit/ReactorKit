//
//  ReactorLocals.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

/// Task-local state used by `ReactorObserving` and `ObservedReactor` to
/// detect whether a read happened inside a `ReactorObserving { ... }`
/// scope. See `ObservedReactor._checkTrackingOnAccess()`.
public enum _ReactorLocals {
  @TaskLocal public static var isInReactorObserving = false

  /// Snapshot of the observing scope at the moment a `Binding` was
  /// created. `@ReactorBindable` / `reactor.binding(get:send:)` capture
  /// the snapshot synchronously inside the view body (while the
  /// TaskLocal is live) and use `restoring { ... }` to re-establish
  /// the scope whenever SwiftUI reads the binding back later from a
  /// child view body. Without this, the deferred read looks like it
  /// came from outside any tracking scope and fires a false-positive
  /// warning on every bound `TextField` / `Toggle`.
  ///
  /// Encapsulates the raw `$isInReactorObserving.withValue` projection
  /// so call sites never touch the TaskLocal's name or syntax directly.
  struct Snapshot {
    private let wasActive: Bool

    static func capture() -> Self {
      .init(wasActive: _ReactorLocals.isInReactorObserving)
    }

    func restoring<T>(_ operation: () throws -> T) rethrows -> T {
      try _ReactorLocals.$isInReactorObserving.withValue(wasActive, operation: operation)
    }
  }
}
