//
//  ObservableState.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

/// Returns `true` if two ObservableState values share the same registrar identity.
@inlinable
public func _$isIdentityEqual<T: ObservableState>(_ lhs: T, _ rhs: T) -> Bool {
  lhs._$observationRegistrar._$id == rhs._$observationRegistrar._$id
}

/// Non-ObservableState values are never identity-equal (falls through to shouldNotifyObservers).
@inlinable
@_disfavoredOverload
public func _$isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  false
}

/// A protocol that structs conform to for per-property observation tracking.
///
/// Types annotated with the ``ObservableState()`` macro automatically synthesize
/// conformance to this protocol. The generated code instruments each stored
/// property's getter and setter to record accesses and notify observers of
/// mutations, enabling SwiftUI to re-render only the views that read changed
/// properties.
public protocol ObservableState {
  /// The registrar that manages observation tracking for this state.
  var _$observationRegistrar: ObservableStateRegistrar { get set }

  /// Called by `_modify` accessor before yielding a nested `ObservableState` member.
  mutating func _$willModify()
}
