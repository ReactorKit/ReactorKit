//
//  ObservableStateRegistrar.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Foundation
#if canImport(Observation)
import Observation
#endif

/// Manages observation tracking for value-type state conforming to
/// ``ObservableState``.
///
/// Although this is a struct, both of its stored fields are
/// reference-semantic boxes:
///
/// - `_nativeBox` wraps Apple's `Observation.ObservationRegistrar` (iOS
///   17+) so per-property willSet/didSet notifications fire against the
///   same registrar instance even after the enclosing state struct is
///   copied during `reduce`. This is how SwiftUI's native observation
///   sees per-property scoping on a value type.
/// - `_mutations` records the keyPaths touched during a reduce round so
///   ``ObservedReactor`` can fan them out on the iOS 13–16 backport
///   channel when it installs the new state. On iOS 17+ this set is
///   redundant but kept for a single code path.
///
/// Both boxes are shared by all copies of the struct; the struct field
/// only holds a reference, so the copy is cheap.
public struct ObservableStateRegistrar: @unchecked Sendable {

  /// The identity of the state instance this registrar belongs to.
  public private(set) var _$id: ObservableStateID

  @usableFromInline
  let _mutations: _MutationStorage

  @usableFromInline
  let _nativeBox: _NativeObservationRegistrarBox

  public init() {
    _$id = ObservableStateID()
    _mutations = _MutationStorage()
    _nativeBox = _NativeObservationRegistrarBox()
  }

  /// Records a keyPath touched during a reduce round. Drives the iOS
  /// 13–16 backport fan-out in ``ObservedReactor``'s `state` setter.
  ///
  /// `_$` prefix marks this as macro-internal ABI — ReactorKit-specific
  /// infrastructure that has no counterpart in Apple's
  /// `Observation.ObservationRegistrar`.
  @inlinable
  public func _$trackMutation(_ keyPath: AnyKeyPath) {
    _mutations.insert(keyPath)
  }

  @inlinable
  public var _$mutatedKeyPaths: Set<AnyKeyPath> {
    _mutations.keyPaths
  }

  @inlinable
  public func _$clearMutations() {
    _mutations.clear()
  }

  /// Registers a read of `keyPath` with the shared native registrar so
  /// SwiftUI's `withObservationTracking` captures a per-property access
  /// on iOS 17+. Called from the macro-generated property `get`.
  @inlinable
  public func access<Subject: ObservableState, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    _nativeBox.access(subject, keyPath: keyPath)
  }

  /// Brackets a property `set` with native willSet/didSet and records
  /// the keyPath for the backport fan-out. `shouldNotifyObservers`
  /// implements the `Equatable` skip (no-op reassignments don't fire).
  ///
  /// `_$` prefix marks this as macro-internal ABI — convenience helper
  /// that bundles identity short-circuit, Equatable skip, backport
  /// fan-out, and native willSet/didSet into a single call the macro
  /// emits from every property setter. Not part of Apple's
  /// `Observation.ObservationRegistrar`.
  @inlinable
  public func _$mutate<Subject: ObservableState, Member, Value>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ value: inout Value,
    _ newValue: Value,
    _ isIdentityEqual: (Value, Value) -> Bool,
    _ shouldNotifyObservers: (Value, Value) -> Bool
  ) {
    if isIdentityEqual(value, newValue) || !shouldNotifyObservers(value, newValue) {
      value = newValue
    } else {
      _$trackMutation(keyPath)
      _nativeBox.willSet(subject, keyPath: keyPath)
      value = newValue
      _nativeBox.didSet(subject, keyPath: keyPath)
    }
  }

  // MARK: - _modify bookends
  //
  // Invoked by the macro-generated `_modify` accessor that wraps
  // every stored property. `willModify` runs before the yield,
  // `didModify` after — together they signal "a mutation is
  // happening on `keyPath`" to both the iOS 17+ native observation
  // path and the iOS 13–16 backport fan-out.
  //
  // The names deliberately avoid `willSet` / `didSet` — that
  // vocabulary belongs to Swift's property-observer block syntax
  // (`var count { willSet { … } }`) at the language level, and to
  // the 2-param phase methods on `Observation.ObservationRegistrar`.
  // These bookends serve a narrower purpose: they are only called
  // from the `_modify` accessor, never from the `set` accessor path
  // (which routes through ``_$mutate(_:keyPath:_:_:_:_:)``). The
  // `Modify` suffix makes that scope explicit.
  //
  // # No post-mutation equality check
  //
  // An alternative design would capture the property's value before
  // yield, compare it to the post-yield value inside `didModify`,
  // and skip observer notifications when they match — suppressing
  // re-renders for no-op compound mutations like `state.count += 0`.
  // We deliberately do not do this.
  //
  // Capturing the pre-yield value forces a copy. For scalar-sized
  // members the cost is nothing; for container-shaped properties —
  // `Array`, `Dictionary`, `Set`, nested structs carrying large
  // payloads — the copy breaks the copy-on-write fast path that
  // makes in-place mutations cheap. `state.items.append(element)`
  // should be O(1): one new buffer slot, one observer fire. Adding
  // a pre/post compare turns it into O(N) — the entire array is
  // duplicated so `didModify` can diff it element by element, and
  // `append`'s reuse-in-place win is lost on the hot path.
  //
  // The cheaper trade is to over-fire: every `_modify` emits a
  // notification regardless of whether the new value actually
  // differs from the old. SwiftUI's downstream view-body diffing
  // catches the redundant render cheaply — an unchanged body exits
  // without touching the render tree — and genuine no-op compound
  // mutations are rare in practice. The failure mode we refuse is
  // under-firing: a view that tracked the mutated property failing
  // to re-render when it should. Over-firing is a missed peephole
  // optimization; under-firing is a correctness bug.
  //
  // # What MUST fire here
  //
  // Both bookends MUST invoke `_nativeBox.willSet` / `_nativeBox.didSet`
  // so iOS 17+ native Observation sees the per-property change. If
  // they stop, in-place mutations (`state.count += 1`, array append,
  // dictionary subscript, etc.) become invisible to SwiftUI on iOS
  // 17+ — the only observable path left is `ObservedReactor`'s coarse
  // `\.state` fan-out, collapsing per-property scoping back to
  // whole-state invalidation.

  @inlinable
  public func willModify<Subject: ObservableState, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) {
    _nativeBox.willSet(subject, keyPath: keyPath)
  }

  /// Overload for nested `ObservableState` members: additionally bumps
  /// the nested state's identity so a `_modify` on the parent registers
  /// as a real mutation even when the nested value is re-assigned
  /// unchanged.
  @inlinable
  public func willModify<Subject: ObservableState, Member: ObservableState>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) {
    _nativeBox.willSet(subject, keyPath: keyPath)
    member._$willModify()
  }

  @inlinable
  public func didModify<Subject: ObservableState, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ member: inout Member
  ) {
    _$trackMutation(keyPath)
    _nativeBox.didSet(subject, keyPath: keyPath)
  }

  /// Called on a nested `ObservableState` before its enclosing `_modify`
  /// yields. Regenerates the id so the containing registrar sees the
  /// child as "changed".
  public mutating func _$willModify() {
    _$id._$willModify()
  }
}

// MARK: - Equatable, Hashable, Codable

extension ObservableStateRegistrar: Equatable {
  @inlinable
  public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension ObservableStateRegistrar: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {}
}

extension ObservableStateRegistrar: Codable {
  @inlinable
  public init(from decoder: Decoder) throws {
    self.init()
  }

  @inlinable
  public func encode(to encoder: Encoder) throws {}
}

// MARK: - _NativeObservationRegistrarBox

/// Reference-semantic wrapper around a native
/// `Observation.ObservationRegistrar` on iOS 17+ / macOS 14+. On earlier
/// OSes the storage is `nil` and every method is a no-op. Being a class,
/// copies of the enclosing `ObservableStateRegistrar` struct all share
/// the same box — which is what lets per-property observation survive
/// value-semantic state copies.
///
/// `access` / `willSet` / `didSet` take any `Subject` and internally
/// cast it to `any Observation.Observable` before opening the existential
/// through a nested generic. The `unsafeBitCast` of the keyPath from
/// `KeyPath<Subject, Member>` to `KeyPath<S, Member>` is safe because
/// `S` is the dynamic type of the subject — the keyPath's root is
/// layout-compatible across the open.
@usableFromInline
final class _NativeObservationRegistrarBox: @unchecked Sendable {

  #if canImport(Observation)
  @usableFromInline
  let _storage: Any?

  @usableFromInline
  init() {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
      _storage = ObservationRegistrar()
    } else {
      _storage = nil
    }
  }

  @usableFromInline
  func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = _storage as? ObservationRegistrar,
      let observable = subject as? any Observation.Observable
    {
      func open<S: Observation.Observable>(_ s: S) {
        registrar.access(
          s,
          keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
        )
      }
      open(observable)
    }
  }

  @usableFromInline
  func willSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = _storage as? ObservationRegistrar,
      let observable = subject as? any Observation.Observable
    {
      func open<S: Observation.Observable>(_ s: S) {
        registrar.willSet(
          s,
          keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
        )
      }
      open(observable)
    }
  }

  @usableFromInline
  func didSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = _storage as? ObservationRegistrar,
      let observable = subject as? any Observation.Observable
    {
      func open<S: Observation.Observable>(_ s: S) {
        registrar.didSet(
          s,
          keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
        )
      }
      open(observable)
    }
  }

  #else
  @usableFromInline
  init() {}
  @usableFromInline
  func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {}
  @usableFromInline
  func willSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {}
  @usableFromInline
  func didSet<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) {}
  #endif
}

// MARK: - _MutationStorage

@usableFromInline
final class _MutationStorage: @unchecked Sendable {
  @usableFromInline
  var _keyPaths = Set<AnyKeyPath>()

  @usableFromInline
  init() {}

  @inlinable
  func insert(_ keyPath: AnyKeyPath) {
    _keyPaths.insert(keyPath)
  }

  @inlinable
  var keyPaths: Set<AnyKeyPath> {
    _keyPaths
  }

  @inlinable
  func clear() {
    _keyPaths.removeAll()
  }
}
