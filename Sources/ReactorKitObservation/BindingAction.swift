//
//  BindingAction.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/12/26.
//

/// An action type that can carry a binding write from a SwiftUI view.
///
/// Conform a `Reactor.Action` enum to `BindableAction` and add a single
/// `binding` case to opt into `@Bindable` two-way binding support:
///
/// ```swift
/// enum Action: BindableAction {
///   case binding(BindingAction<State>)
///   case submit
/// }
/// ```
///
/// In `reduce`, apply the captured assignment with one line:
///
/// ```swift
/// case .binding(let action):
///   action.apply(to: &state)
/// ```
public protocol BindableAction {
  /// The state type whose properties this action can write.
  associatedtype State

  /// Wraps a `BindingAction` into the conforming `Action` enum.
  ///
  /// Typically implemented as a synthesized enum case:
  /// `case binding(BindingAction<State>)`.
  static func binding(_ action: BindingAction<State>) -> Self
}

/// A type-erased keyPath assignment that flows through a Reactor's action
/// pipeline and is applied to state inside `reduce`.
///
/// `BindingAction` stores a writable keyPath plus a closure that performs
/// the assignment. Construct via ``set(_:_:)``, apply via ``apply(to:)``.
/// Two actions compare equal when they target the same keyPath *and* were
/// both constructed via the `Equatable` overload with equal values.
public struct BindingAction<Root>: @unchecked Sendable {

  /// The keyPath being written.
  public let keyPath: PartialKeyPath<Root>

  @usableFromInline
  let _apply: (inout Root) -> Void

  /// Type-erased value capture, used only by the equality comparator.
  /// `nil` when the action was created via the non-Equatable overload.
  @usableFromInline
  let _value: Any?

  /// Compares this action's captured value to `other._value`. Returns `false`
  /// safely when the other action carried a non-matching type or no value.
  @usableFromInline
  let _valueIsEqualTo: (Any?) -> Bool

  @usableFromInline
  init(
    keyPath: PartialKeyPath<Root>,
    apply: @escaping (inout Root) -> Void,
    value: Any?,
    valueIsEqualTo: @escaping (Any?) -> Bool
  ) {
    self.keyPath = keyPath
    _apply = apply
    _value = value
    _valueIsEqualTo = valueIsEqualTo
  }

  /// Builds a binding action that writes `value` to `keyPath` when applied.
  ///
  /// Non-`Equatable` overload — two actions built this way are never equal,
  /// regardless of keyPath or value.
  @_disfavoredOverload
  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self {
    Self(
      keyPath: keyPath,
      apply: { $0[keyPath: keyPath] = value },
      value: nil,
      valueIsEqualTo: { _ in false }
    )
  }

  /// Builds a binding action that writes `value` to `keyPath` when applied.
  ///
  /// `Equatable` overload — captures a comparator so two such actions can be
  /// compared for structural equality.
  public static func set<Value: Equatable>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self {
    Self(
      keyPath: keyPath,
      apply: { $0[keyPath: keyPath] = value },
      value: value,
      valueIsEqualTo: { other in (other as? Value) == value }
    )
  }

  /// Applies the captured assignment to the given state.
  @inlinable
  public func apply(to state: inout Root) {
    _apply(&state)
  }
}

extension BindingAction {

  /// Pattern-matching operator: `if \State.text ~= action { ... }`.
  ///
  /// Returns `true` when the action targets the same keyPath, regardless of
  /// the value being assigned.
  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    action: Self
  ) -> Bool {
    action.keyPath == keyPath
  }
}

extension BindingAction: Equatable {
  /// Two binding actions are equal when they target the same keyPath and
  /// were both constructed via the `Equatable` `set` overload with equal
  /// values. Actions built via the non-Equatable overload are never equal.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs._valueIsEqualTo(rhs._value)
  }
}
