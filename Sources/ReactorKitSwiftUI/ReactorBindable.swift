//
//  ReactorBindable.swift
//  ReactorKitSwiftUI
//
//  Created by Kanghoon Oh on 4/12/26.
//

import SwiftUI

import ReactorKit
import ReactorKitObservation

/// The ReactorKit equivalent of SwiftUI's iOS 17+ `@Bindable`, available
/// on every deployment target the package supports. Apply it to an
/// ``ObservedReactor`` whose state conforms to `ObservableState` and
/// whose action conforms to `BindableAction` to get `$reactor.text`-style
/// two-way bindings.
///
/// ```swift
/// struct CounterView: View {
///   @ReactorBindable var reactor: ObservedReactor<CounterReactor>
///
///   var body: some View {
///     ReactorObserving {
///       TextField("Name", text: $reactor.text)
///       Toggle("Enabled", isOn: $reactor.isEnabled)
///     }
///   }
/// }
/// ```
///
/// The name is deliberately distinct from `SwiftUI.Bindable` so both can
/// coexist in the same file on iOS 17+ without module-qualification.
///
/// ## Binding identity — how `$reactor.foo` stays location-based
///
/// In both DEBUG and RELEASE builds, the subscript returns a location-
/// based `Binding<Subject>` produced by `Binding`'s own keyPath-rooted
/// projection (not a `(get:set:)` closure pair). This is load-bearing:
/// SwiftUI diffs bindings by location identity across successive parent
/// body re-evaluations, and skips re-rendering child views (e.g. a
/// `TextField` inside `_highlightsOnUpdate()`) whose input binding is
/// "the same".
///
/// In DEBUG, the binding is routed through a labeled subscript on
/// ``ObservedReactor`` (`[isInReactorObserving:keyPath:]`) that, on each
/// read/write, re-installs the `_ReactorLocals.isInReactorObserving`
/// task-local value captured at binding-creation time. Because SwiftUI
/// evaluates the binding later, outside the original `ReactorObserving`
/// scope, the re-install is what prevents a spurious "state accessed
/// outside ReactorObserving" warning from firing on every bound control.
/// Crucially — unlike a closure wrapper — the binding remains a
/// keyPath-rooted `Binding`, so SwiftUI's location-identity diffing
/// still works and bound children are not re-evaluated on parent body
/// re-evals.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
@dynamicMemberLookup
@propertyWrapper
public struct ReactorBindable<R: Reactor> where R.State: ObservableState {

  @ObservedObject private var observer: Observer<ObservedReactor<R>>

  public var wrappedValue: ObservedReactor<R> {
    get { observer.object }
    set { observer.object = newValue }
  }

  public var projectedValue: Self { self }

  public init(wrappedValue: ObservedReactor<R>) {
    self.observer = Observer(wrappedValue)
  }

  public init(_ wrappedValue: ObservedReactor<R>) {
    self.init(wrappedValue: wrappedValue)
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public subscript<Subject>(
    dynamicMember keyPath: ReferenceWritableKeyPath<ObservedReactor<R>, Subject>
  ) -> Binding<Subject> {
    #if DEBUG
    // Route through the labeled subscript on `ObservedReactor` (defined
    // below). Swift synthesizes a keyPath-rooted `Binding` via the
    // labeled-subscript-as-keyPath form, which Binding's dynamic member
    // projection accepts. The resulting Binding is location-based AND
    // its getter/setter re-install the captured
    // `_ReactorLocals.isInReactorObserving` on each deferred read.
    return $observer.object[
      isInReactorObserving: _ReactorLocals.isInReactorObserving,
      keyPath: keyPath
    ]
    #else
    return $observer.object[dynamicMember: keyPath]
    #endif
  }
}

// MARK: - TaskLocal-restoring subscript

#if DEBUG
/// Labeled subscript used by ``ReactorBindable``'s DEBUG-only binding
/// projection to capture-and-restore the
/// `_ReactorLocals.isInReactorObserving` task-local across deferred
/// binding reads. See the type-level doc on ``ReactorBindable`` for why.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ObservedReactor {
  fileprivate subscript<Member>(
    isInReactorObserving isInReactorObserving: Bool,
    keyPath keyPath: ReferenceWritableKeyPath<ObservedReactor, Member>
  ) -> Member {
    get {
      _ReactorLocals.$isInReactorObserving.withValue(isInReactorObserving) {
        self[keyPath: keyPath]
      }
    }
    set {
      _ReactorLocals.$isInReactorObserving.withValue(isInReactorObserving) {
        self[keyPath: keyPath] = newValue
      }
    }
  }
}
#endif

// MARK: - Observer

/// A trivial `ObservableObject` box whose only reason to exist is to give
/// SwiftUI an `ObservedObject.Wrapper` it can project through, so the
/// resulting `Binding` gets a stable location identity. It never sends
/// `objectWillChange` — state observation is delivered by the wrapped
/// value's own registrar, not this box.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private final class Observer<Object>: ObservableObject {
  var object: Object
  init(_ object: Object) { self.object = object }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Observer: Equatable where Object: AnyObject {
  static func == (lhs: Observer, rhs: Observer) -> Bool {
    lhs.object === rhs.object
  }
}
