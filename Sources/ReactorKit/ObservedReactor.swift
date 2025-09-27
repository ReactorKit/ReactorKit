//
//  ObservedReactor.swift
//  ReactorKit
//
//  Created by Kanghoon Oh on 2025/09/27.
//

#if !os(Linux)
#if canImport(SwiftUI)
import SwiftUI

import RxSwift

/// A property wrapper that bridges ReactorKit with SwiftUI
///
/// ObservedReactor allows you to use existing Reactors designed for UIKit
/// in SwiftUI views without modification. It automatically observes state changes
/// and triggers SwiftUI view updates.
///
/// Example usage:
/// ```swift
/// struct ContentView: View {
///     @ObservedReactor var reactor = CounterReactor()
///
///     var body: some View {
///         VStack {
///             Text("Count: \($reactor.state.value)")
///             Button("Increase") {
///                 $reactor.send(.increase)
///             }
///         }
///     }
/// }
/// ```
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct ObservedReactor<R: Reactor>: DynamicProperty {

  /// ObservableObject wrapper that manages Reactor state and triggers SwiftUI updates
  @dynamicMemberLookup
  public final class Wrapper: ObservableObject {
    fileprivate let reactor: R
    @Published public private(set) var state: R.State
    private var disposeBag = DisposeBag()

    init(_ reactor: R) {
      self.reactor = reactor
      self.state = reactor.currentState

      // Subscribe to state changes
      reactor.state
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] newState in
          self?.state = newState
        })
        .disposed(by: disposeBag)
    }

    /// Send an action to the reactor
    public func send(_ action: R.Action) {
      reactor.action.onNext(action)
    }

    /// Create a binding for a specific state property
    /// - Parameters:
    ///   - get: A closure that extracts a value from the state
    ///   - send: A closure that creates an action from a value
    /// - Returns: A SwiftUI Binding
    public func binding<Value>(
      get: @escaping (R.State) -> Value,
      send: @escaping (Value) -> R.Action,
    ) -> Binding<Value> {
      Binding(
        get: { get(self.state) },
        set: { self.send(send($0)) },
      )
    }

    /// Create a binding using KeyPath for convenience
    /// - Parameters:
    ///   - keyPath: KeyPath to the state property
    ///   - send: A closure that creates an action from a value
    /// - Returns: A SwiftUI Binding
    public func binding<Value>(
      _ keyPath: KeyPath<R.State, Value>,
      send: @escaping (Value) -> R.Action,
    ) -> Binding<Value> {
      binding(
        get: { $0[keyPath: keyPath] },
        send: send,
      )
    }

  }

  @ObservedObject private var wrapper: Wrapper

  public init(wrappedValue: R) {
    self.wrapper = Wrapper(wrappedValue)
  }

  public var wrappedValue: R {
    wrapper.reactor
  }

  public var projectedValue: Wrapper {
    wrapper
  }
}

// MARK: - Convenience Extensions

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ObservedReactor.Wrapper {
  /// Dynamic member lookup for state properties
  /// Example: `$reactor.value` instead of `$reactor.state.value`
  public subscript<Value>(dynamicMember keyPath: KeyPath<R.State, Value>) -> Value {
    state[keyPath: keyPath]
  }
}

#endif // canImport(SwiftUI)
#endif // !os(Linux)
