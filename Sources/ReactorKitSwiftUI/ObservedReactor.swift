//
//  ObservedReactor.swift
//  ReactorKitSwiftUI
//
//  Created by Kanghoon Oh on 4/11/26.
//

#if canImport(Observation)
import Observation
#endif
import SwiftUI

import ReactorKit
import ReactorKitObservation
@preconcurrency import RxSwift

/// An observable wrapper that bridges a `Reactor` to SwiftUI.
///
/// `ObservedReactor` subscribes to the reactor's RxSwift state stream and notifies SwiftUI
/// of state changes through observation tracking.
///
/// On iOS 17+, SwiftUI automatically tracks state access via native Observation.
/// On iOS 13~16, wrap the view body with ``ReactorObserving`` to enable tracking.
///
/// ```swift
/// struct CounterView: View {
///   let reactor: ObservedReactor<CounterViewReactor>
///
///   var body: some View {
///     ReactorObserving {
///       Text("\(reactor.count)")
///       Button("+") { reactor.send(.increase) }
///     }
///   }
/// }
/// ```
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
@dynamicMemberLookup
public final class ObservedReactor<R: Reactor> where R.State: ObservableState {

  private let _registrar = _ReactorRegistrar()

  /// Backing storage for `state`.
  private var _state: R.State

  /// Instance-scoped render-path detector. Cache lifetime tracks this
  /// `ObservedReactor`, so dismissed screens free their entries instead
  /// of accumulating process-wide. `#if DEBUG` because the detector is
  /// only consulted by the DEBUG-only missing-scope check below.
  #if DEBUG
  private var _renderPathDetector = _SwiftUIRenderPathDetector()
  #endif

  /// DEBUG-only missing-scope check. Called from every read path (the
  /// `state` getter, both dynamic-member subscripts, closure-based
  /// `binding(get:send:)` helpers, and `ReactorBindable`'s projection
  /// subscript). Fires whenever a read happens from inside a SwiftUI
  /// render but outside a `ReactorObserving` scope — no instance-level
  /// dedup, so the warning re-fires on every body re-evaluation
  /// triggered by a state mutation, making the violation hard to miss.
  ///
  /// Performance notes:
  ///   - Entire body is `#if DEBUG`, so release builds pay zero cost.
  ///   - First guard is `ReactorObservingConfiguration.isTrackingCheckEnabled`.
  ///     When set to `false`, the check collapses to a single Bool load
  ///     + branch, short-circuiting before any TaskLocal read, stack
  ///     walk, or cache lookup. This is the "turn it off entirely"
  ///     escape hatch.
  ///   - The stack walk + AttributeGraph scan from `_SwiftUIRenderPathDetector`
  ///     only runs when outside a `ReactorObserving` scope and uses a
  ///     per-stack-hash cache internally, so repeated reads from the
  ///     same call site hit the cache and are O(1).
  @inline(__always)
  func _checkTrackingOnAccess() {
    #if DEBUG
    guard
      ReactorObservingConfiguration.isTrackingCheckEnabled,
      !_ReactorLocals.isInReactorObserving,
      _renderPathDetector.isInRenderPath()
    else { return }
    _runtimeWarning(
      "ObservedReactor<\(R.self)> state was accessed from a SwiftUI view but is "
        + "not being tracked. Wrap the view body in ReactorObserving { ... } to "
        + "enable state tracking. If your project targets iOS 17 or later "
        + "exclusively and relies on native Observation, set "
        + "ReactorObservingConfiguration.isTrackingCheckEnabled = false to silence "
        + "this warning."
    )
    #endif
  }

  /// The current state of the reactor.
  ///
  /// Reading `reactor.state` takes a coarse `\.state` access on the
  /// class-level registrar. Prefer `reactor.<propertyName>` (via the
  /// per-property dynamic-member subscript below) — it routes through
  /// the state struct's own registrar so SwiftUI invalidates only views
  /// that read the specific property that changed.
  public private(set) var state: R.State {
    get {
      _checkTrackingOnAccess()
      _registrar.access(self, keyPath: \.state)
      return _state
    }
    set {
      // Two notification channels fire from this setter:
      //
      //   1. The per-property backport fan-out (`willSetAnyKeyPath`)
      //      drives observation on iOS 13–16, where the state struct's
      //      own native registrar is absent. The keyPath set was filled
      //      in during `reduce` by each macro-generated setter / _modify
      //      calling `_$trackMutation`.
      //
      //   2. The coarse `withMutation(\.state)` fires for readers that
      //      tracked the whole `reactor.state` property — e.g. any
      //      direct `reactor.state` read or whole-state replacements in
      //      `reduce` that bypass the per-property setters.
      //
      // Per-property observation on iOS 17+ is ALREADY delivered by
      // this point — the macro's `_$mutate` / `willModify` / `didModify`
      // path fired native willSet/didSet inside `reduce`. Nothing here
      // needs to repeat it.
      let registrar = newValue._$observationRegistrar
      if !registrar._$mutatedKeyPaths.isEmpty {
        for keyPath in registrar._$mutatedKeyPaths {
          _registrar.willSetAnyKeyPath(keyPath)
        }
        registrar._$clearMutations()
      }
      _registrar.withMutation(of: self, keyPath: \.state) {
        _state = newValue
      }
    }
  }

  /// The underlying reactor instance.
  private let reactor: R

  private var disposeBag = DisposeBag()

  /// Creates an observed reactor, subscribing to the reactor's state
  /// stream and routing every emission through the `state` setter so
  /// observation notifications fire on the main actor.
  ///
  /// State emissions are hopped onto `MainScheduler.instance` before the
  /// `assumeIsolated` call below. The Reactor pipeline does not reschedule
  /// on its own, so `mutate(_:)` can return observables that emit from
  /// background threads. Observing on main here guarantees the
  /// `@MainActor` contract regardless of how the reactor's mutations
  /// dispatch.
  public init(reactor: R) {
    self.reactor = reactor
    self._state = reactor.initialState
    reactor.state
      .observe(on: MainScheduler.instance)
      .subscribe(onNext: { [weak self] state in
        MainActor.assumeIsolated {
          self?.state = state
        }
      })
      .disposed(by: disposeBag)
  }

  /// Sends an action to the reactor.
  public func send(_ action: R.Action) {
    reactor.action.onNext(action)
  }

  /// Per-property dynamic-member subscript.
  ///
  /// The read of `_state[keyPath: keyPath]` invokes the macro-generated
  /// `get` accessor on the state struct, which records the access on
  /// the state's own `ObservableStateRegistrar` — driving the native
  /// `Observation.ObservationRegistrar` on iOS 17+ and the backport
  /// `accessAnyKeyPath` scope below on iOS 13–16. ObservedReactor's own
  /// `_registrar` is deliberately NOT consulted here: per-property
  /// scoping is owned by the state struct's shared registrar so writes
  /// to one property don't invalidate views that read another.
  public subscript<Value>(dynamicMember keyPath: KeyPath<R.State, Value>) -> Value {
    _checkTrackingOnAccess()
    _registrar.accessAnyKeyPath(keyPath as AnyKeyPath)
    return _state[keyPath: keyPath]
  }

}

// MARK: - @Bindable support

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ObservedReactor
  where
  R.Action: BindableAction,
  R.Action.State == R.State
{
  /// Read-write dynamic-member subscript that powers
  /// `@ReactorBindable var reactor` / `$reactor.text`.
  ///
  /// The setter performs an **optimistic local write** into `_state`
  /// *and* dispatches an `Action.binding(.set(keyPath, newValue))` into
  /// the Rx pipeline. The optimistic write is load-bearing: Rx is
  /// asynchronous in general, and SwiftUI controls like `TextField` /
  /// `FocusState` read the binding back in the same update cycle —
  /// without the synchronous local write the caret jumps and IME
  /// composition breaks. When `reduce` eventually echoes the same
  /// value, the macro setter's equality skip dedupes; when `reduce`
  /// transforms the value, the UI shows the raw value for one tick
  /// then snaps to the transformed one.
  public subscript<Value: Sendable>(
    dynamicMember keyPath: WritableKeyPath<R.State, Value>
  ) -> Value {
    get {
      // No `_checkTrackingOnAccess()` here: SwiftUI re-reads location-
      // based bindings (`$reactor.text`) outside the original
      // `ReactorObserving` TaskLocal scope, which would otherwise
      // trip a false-positive missing-scope warning on every bound
      // control. The read-only `KeyPath` subscript and the `state`
      // getter still warn, so direct misuse like `reactor.text` from
      // outside `ReactorObserving { }` is still caught.
      _registrar.accessAnyKeyPath(keyPath as AnyKeyPath)
      return _state[keyPath: keyPath]
    }
    set {
      var local = _state
      local[keyPath: keyPath] = newValue // macro setter fires per-property observation
      self.state = local // runs fan-out + coarse \.state
      self.send(R.Action.binding(.set(keyPath, newValue)))
    }
  }
}

// MARK: - Observable (iOS 17+)

#if canImport(Observation)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ObservedReactor: Observation.Observable {}
#endif

// MARK: - binding(get:send:) helpers
//
// Vends closure-based `Binding`s that dispatch a supplied action on
// write. Prefer `@ReactorBindable var reactor` + `$reactor.foo` for new
// code — the property-wrapper path produces diffable bindings that let
// SwiftUI skip re-rendering unrelated child views (see
// `ReactorBindable.swift` for why that matters). These helpers remain
// useful when the property write should translate into something other
// than the default `Action.binding(.set(keyPath, newValue))` — e.g., a
// transform or a domain-specific action.
//
// Also the designated escape hatch for binding non-`Sendable` state
// properties: unlike `$reactor.foo` (which requires `Value: Sendable`
// because `BindingAction.set` does), these helpers impose no such
// constraint — the write routes through a user-supplied action instead
// of a generic `BindingAction`.
//
// Reads from `_state` directly so the macro-generated getter records
// the access on the state struct's registrar instead of taking a
// coarse `\.state` access on the class.

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ObservedReactor {
  public func binding<Value>(
    get keyPath: KeyPath<R.State, Value>,
    send action: @escaping (Value) -> R.Action
  ) -> Binding<Value> {
    _checkTrackingOnAccess()
    return Binding(
      get: { self._state[keyPath: keyPath] },
      set: { self.send(action($0)) }
    )
  }

  public func binding<Value>(
    get keyPath: KeyPath<R.State, Value>,
    send action: R.Action
  ) -> Binding<Value> {
    _checkTrackingOnAccess()
    return Binding(
      get: { self._state[keyPath: keyPath] },
      set: { _ in self.send(action) }
    )
  }
}
