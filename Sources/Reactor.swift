//
//  Reactor.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 06/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import RxSwift

public struct NoAction {}
public struct NoMutation {}

public typealias _Reactor = Reactor
public protocol Reactor: class, AssociatedObjectStore {
  associatedtype Action
  associatedtype Mutation = Action
  associatedtype State

  /// The action from the view. Bind user inputs to this subject.
  var action: ActionSubject<Action> { get }

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

  /// Transforms the mutation stream. Implement this method to transform or combine with other
  /// observables. This method is called once before the state stream is created.
  func transform(mutation: Observable<Mutation>) -> Observable<Mutation>

  /// Generates a new state with the previous state and the action. It should be purely functional
  /// so it should not perform any side-effects here. This method is called every time when the
  /// mutation is committed.
  func reduce(state: State, mutation: Mutation) -> State

  /// Transforms the state stream. Use this function to perform side-effects such as logging. This
  /// method is called once after the state stream is created.
  func transform(state: Observable<State>) -> Observable<State>
}


// MARK: - Associated Object Keys

private var actionKey = "action"
private var currentStateKey = "currentState"
private var stateKey = "state"
private var disposeBagKey = "disposeBag"


// MARK: - Default Implementations

extension Reactor {
  public var action: ActionSubject<Action> {
    return self.associatedObject(forKey: &actionKey, default: .init())
  }

  public private(set) var currentState: State {
    get { return self.associatedObject(forKey: &currentStateKey, default: self.initialState) }
    set { self.setAssociatedObject(newValue, forKey: &currentStateKey) }
  }

  public var state: Observable<State> {
    get { return self.associatedObject(forKey: &stateKey, default: self.createStateStream()) }
  }

  private var disposeBag: DisposeBag {
    get { return self.associatedObject(forKey: &disposeBagKey, default: DisposeBag()) }
    set { self.setAssociatedObject(newValue, forKey: &disposeBagKey) }
  }

  public func createStateStream() -> Observable<State> {
    let action = self.action.asObservable()
    let transformedAction = self.transform(action: action)
    let mutation = transformedAction
      .flatMap { [weak self] action -> Observable<Mutation> in
        guard let `self` = self else { return .empty() }
        return self.mutate(action: action).catchError { _ in .empty() }
      }
    let transformedMutation = self.transform(mutation: mutation)
    let state = transformedMutation
      .scan(self.initialState) { [weak self] state, mutation -> State in
        guard let `self` = self else { return state }
        return self.reduce(state: state, mutation: mutation)
      }
      .catchError { _ in .empty() }
      .startWith(self.initialState)
      .observeOn(MainScheduler.instance)
    let transformedState = self.transform(state: state)
      .do(onNext: { [weak self] state in
        self?.currentState = state
      })
      .replay(1)
    transformedState.connect().addDisposableTo(self.disposeBag)
    return transformedState
  }

  public func transform(action: Observable<Action>) -> Observable<Action> {
    return action
  }

  public func mutate(action: Action) -> Observable<Mutation> {
    return .empty()
  }

  public func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
    return mutation
  }

  public func reduce(state: State, mutation: Mutation) -> State {
    return state
  }

  public func transform(state: Observable<State>) -> Observable<State> {
    return state
  }
}

extension Reactor where Action == Mutation {
  public func mutate(action: Action) -> Observable<Mutation> {
    return .just(action)
  }
}
