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
public protocol Reactor: class {
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

  /// A scheduler for reducing and observing the state stream. Defaults to `CurrentThreadScheduler`.
  var scheduler: Scheduler { get }

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
  static let action = WeakMapTable<AnyReactor, AnyObject>()
  static let currentState = WeakMapTable<AnyReactor, Any>()
  static let state = WeakMapTable<AnyReactor, AnyObject>()
  static let disposeBag = WeakMapTable<AnyReactor, DisposeBag>()
  static let isStubEnabled = WeakMapTable<AnyReactor, Bool>()
  static let stub = WeakMapTable<AnyReactor, AnyObject>()
}


// MARK: - Default Implementations

extension Reactor {
  private var _action: ActionSubject<Action> {
    if self.isStubEnabled {
      return self.stub.action
    } else {
      return MapTables.action.forceCastedValue(forKey: self, default: .init())
    }
  }
  public var action: ActionSubject<Action> {
    // Creates a state stream automatically
    _ = self._state

    // It seems that Swift has a bug in associated object when subclassing a generic class. This is
    // a temporary solution to bypass the bug. See #30 for details.
    return self._action
  }

  public internal(set) var currentState: State {
    get { return MapTables.currentState.forceCastedValue(forKey: self, default: self.initialState) }
    set { MapTables.currentState.setValue(newValue, forKey: self) }
  }

  private var _state: Observable<State> {
    if self.isStubEnabled {
      return self.stub.state.asObservable()
    } else {
      return MapTables.state.forceCastedValue(forKey: self, default: self.createStateStream())
    }
  }
  public var state: Observable<State> {
    // It seems that Swift has a bug in associated object when subclassing a generic class. This is
    // a temporary solution to bypass the bug. See #30 for details.
    return self._state
  }

  public var scheduler: Scheduler {
    return CurrentThreadScheduler.instance
  }

  fileprivate var disposeBag: DisposeBag {
    return MapTables.disposeBag.value(forKey: self, default: DisposeBag())
  }

  public func createStateStream() -> Observable<State> {
    let action = self._action.observe(on: self.scheduler)
    let transformedAction = self.transform(action: action)
    let mutation = transformedAction
      .flatMap { [weak self] action -> Observable<Mutation> in
        guard let `self` = self else { return .empty() }
        return self.mutate(action: action).catch { _ in .empty() }
      }
    let transformedMutation = self.transform(mutation: mutation)
    let state = transformedMutation         
      .scan(self.initialState) { [weak self] state, mutation -> State in
        guard let `self` = self else { return state }
        return self.reduce(state: state, mutation: mutation)
      }
      .catch { _ in .empty() }
      .startWith(self.initialState)
    let transformedState = self.transform(state: state)
      .do(onNext: { [weak self] state in
        self?.currentState = state
      })
      .replay(1)
    transformedState.connect().disposed(by: self.disposeBag)
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


// MARK: - Stub

extension Reactor {
  public var isStubEnabled: Bool {
    get { return MapTables.isStubEnabled.value(forKey: self, default: false) }
    set { MapTables.isStubEnabled.setValue(newValue, forKey: self) }
  }

  public var stub: Stub<Self> {
    return MapTables.stub.forceCastedValue(forKey: self, default: .init(reactor: self, disposeBag: self.disposeBag))
  }
}
