//
//  Reactor.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 06/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import RxSwift
import WeakMapTable

@available(*, obsoleted: 0, renamed: "Never")
public typealias NoAction = Never

@available(*, obsoleted: 0, renamed: "Never")
public typealias NoMutation = Never

/// A Reactor is an UI-independent layer which manages the state of a view. The foremost role of a
/// reactor is to separate control flow from a view. Every view has its corresponding reactor and
/// delegates all logic to its reactor. A reactor has no dependency to a view, so it can be easily
/// tested.
public protocol Reactor: AnyObject {
  /// An action represents user actions.
  associatedtype Action

  /// A mutation represents state changes.
  associatedtype Mutation = Action

  /// A State represents the current state of a view.
  associatedtype State

  typealias Scheduler = ImmediateSchedulerType

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


// MARK: - Map Tables

private typealias AnyReactor = AnyObject

private enum MapTables {
  static let streams = WeakMapTable<AnyReactor, AnyObject>()
  static let currentState = WeakMapTable<AnyReactor, Any>()
  static let disposeBag = WeakMapTable<AnyReactor, DisposeBag>()
  static let isStubEnabled = WeakMapTable<AnyReactor, Bool>()
  static let stub = WeakMapTable<AnyReactor, AnyObject>()
}


// MARK: - ReactorStreams

private struct ReactorStreams<Action, Mutation, State> {
  let action: ActionSubject<Action>
  let mutation: Observable<Mutation>
  let state: Observable<State>
}

// MARK: - Default Implementations

extension Reactor {
  private var streams: ReactorStreams<Action, Mutation, State> {
    if isStubEnabled {
      return ReactorStreams(
        action: stub.action,
        mutation: Observable.empty(),
        state: stub.state.asObservable())
    } else {
      return MapTables.streams.forceCastedValue(forKey: self, default: createReactorStreams())
    }
  }

  public var action: ActionSubject<Action> {
    streams.action
  }

  public internal(set) var currentState: State {
    get { MapTables.currentState.forceCastedValue(forKey: self, default: initialState) }
    set { MapTables.currentState.setValue(newValue, forKey: self) }
  }

  public var mutation: Observable<Mutation> {
    streams.mutation
  }

  public var state: Observable<State> {
    streams.state
  }

  fileprivate var disposeBag: DisposeBag {
    MapTables.disposeBag.value(forKey: self, default: DisposeBag())
  }

  private func createReactorStreams() -> ReactorStreams<Action, Mutation, State> {
    let actionSubject = ActionSubject<Action>()
    let action = actionSubject.asObservable()
    let transformedAction = transform(action: action)
    let mutation = transformedAction
      .flatMap { [weak self] action -> Observable<Mutation> in
        guard let self = self else { return .empty() }
        return self.mutate(action: action).catch { _ in .empty() }
      }
    let transformedMutation = transform(mutation: mutation)
    let state = transformedMutation
      .scan(initialState) { [weak self] state, mutation -> State in
        guard let self = self else { return state }
        return self.reduce(state: state, mutation: mutation)
      }
      .catch { _ in .empty() }
      .startWith(initialState)
    let transformedState = transform(state: state)
      .do(onNext: { [weak self] state in
        self?.currentState = state
      })
      .replay(1)
    transformedState.connect().disposed(by: disposeBag)
    return ReactorStreams(action: actionSubject, mutation: transformedMutation, state: transformedState)
  }

  public func transform(action: Observable<Action>) -> Observable<Action> {
    action
  }

  public func mutate(action: Action) -> Observable<Mutation> {
    .empty()
  }

  public func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
    mutation
  }

  public func reduce(state: State, mutation: Mutation) -> State {
    state
  }

  public func transform(state: Observable<State>) -> Observable<State> {
    state
  }
}

extension Reactor where Action == Mutation {
  public func mutate(action: Action) -> Observable<Mutation> {
    .just(action)
  }
}


// MARK: - Stub

extension Reactor {
  public var isStubEnabled: Bool {
    get { MapTables.isStubEnabled.value(forKey: self, default: false) }
    set { MapTables.isStubEnabled.setValue(newValue, forKey: self) }
  }

  public var stub: Stub<Self> {
    MapTables.stub.forceCastedValue(forKey: self, default: .init(reactor: self, disposeBag: disposeBag))
  }
}
