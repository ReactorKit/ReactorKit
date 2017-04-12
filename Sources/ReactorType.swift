//
//  Reactor.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 06/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import RxSwift

public protocol ReactorType: class {
  associatedtype Action
  associatedtype Mutation
  associatedtype State

  /// The action from the view. Bind user inputs to this subject.
  var action: AnyObserver<Action> { get }

  /// The initial state.
  var initialState: State { get }

  /// The current state. This value is changed just after the state stream emits a new state.
  var currentState: State { get }

  /// The state stream. Use this observable to observe the state changes.
  var state: Observable<State> { get }

  /// Transforms the action. Use this function to combine with other observables. This method is
  /// called once before the state stream is created.
  func transform(action: Observable<Action>) -> Observable<Action>

  /// Commits mutation from the action. This is the best place to perform side-effects such as
  /// async tasks.
  func mutate(action: Action) -> Observable<Mutation>

  /// Generates a new state with the previous state and the action. It should be purely functional
  /// so it should not perform any side-effects here. This method is called every time when the
  /// mutation is committed.
  func reduce(state: State, mutation: Mutation) -> State

  /// Transforms the state stream. Use this function to perform side-effects such as logging. This
  /// method is called once after the state stream is created.
  func transform(state: Observable<State>) -> Observable<State>
}

extension ReactorType {
  public func transform(action: Observable<Action>) -> Observable<Action> {
    return action
  }

  public func transform(state: Observable<State>) -> Observable<State> {
    return state
  }
}

extension ReactorType where Action == Mutation {
  public func mutate(action: Action) -> Observable<Mutation> {
    return .just(action)
  }
}
