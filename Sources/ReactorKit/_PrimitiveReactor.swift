//
//  _PrimitiveReactor.swift
//  ReactorKit
//
//  Created by Kanghoon Oh on 10/2/25.
//

import RxSwift

/// Minimal Reactor interface for SwiftUI integration.
///
/// - Important: This is an **internal implementation protocol** for ReactorKit's SwiftUI integration.
///   Do not conform to this protocol directly.
/// - Purpose: Exposes only the minimal surface API required by `ObservedReactor` in SwiftUI.
/// - Overview: Provides the action input stream and a snapshot of the current state so that
///   state changes can be observed and drive view updates.
/// - Note: Types conforming to `Reactor` automatically satisfy these requirements.
/// - Threading: Prefer reading `currentState` and performing UI bindings on the main thread.
public protocol _PrimitiveReactor<Action, State>: AnyObject {
  associatedtype Action
  associatedtype State

  /// The input stream for view events. In SwiftUI bindings, call `onNext(_:)` in the setter.
  var action: ActionSubject<Action> { get }

  /// A read-only snapshot of the most recently emitted state. Used by the getter side of
  /// SwiftUI bindings.
  var currentState: State { get }
}
