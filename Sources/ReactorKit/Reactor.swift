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

  /// A event represents state changes.
  associatedtype Event = Action
  
  @available(*, obsoleted: 0, renamed: "Event")
  typealias Mutation = Event

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

  /// Commits event from the action. This is the best place to perform side-effects such as
  /// async tasks.
  func mutate(action: Action) -> Observable<Event>

  /// Transforms the event stream. Implement this method to transform or combine with other
  /// observables. This method is called once before the state stream is created.
  func transform(event: Observable<Event>) -> Observable<Event>
  
  @available(*, deprecated, message: "Use 'transform(event:) -> Observable<Event>' instead.")
  func transform(mutation: Observable<Event>) -> Observable<Event>

  /// Generates a new state with the previous state and the action. It should be purely functional
  /// so it should not perform any side-effects here. This method is called every time when the
  /// event is committed.
  func reduce(state: State, event: Event) -> State
  
  @available(*, deprecated, message: "Use 'reduce(state:event:) -> State' instead.")
  func reduce(state: State, mutation: Event) -> State
  
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

private struct ReactorStreams<Action, State> {
  let action: ActionSubject<Action>
  let state: Observable<State>
}

// MARK: - Default Implementations

extension Reactor {
  private var streams: ReactorStreams<Action, State> {
    if isStubEnabled {
      return ReactorStreams(action: stub.action, state: stub.state.asObservable())
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

  public var state: Observable<State> {
    streams.state
  }

  fileprivate var disposeBag: DisposeBag {
    MapTables.disposeBag.value(forKey: self, default: DisposeBag())
  }

  private func createReactorStreams() -> ReactorStreams<Action, State> {
    let actionSubject = ActionSubject<Action>()
    let action = actionSubject.asObservable()
    let transformedAction = transform(action: action)
    let event = transformedAction
      .flatMap { [weak self] action -> Observable<Event> in
        guard let self = self else { return .empty() }
        return self.mutate(action: action).catch { _ in .empty() }
      }
    let transformedEvent = transform(event: event)
    let state = transformedEvent
      .scan(initialState) { [weak self] state, event -> State in
        guard let self = self else { return state }
        return self.reduce(state: state, event: event)
      }
      .catch { _ in .empty() }
      .startWith(initialState)
    let transformedState = transform(state: state)
      .do(onNext: { [weak self] state in
        self?.currentState = state
      })
      .replay(1)
    transformedState.connect().disposed(by: disposeBag)
    return ReactorStreams(action: actionSubject, state: transformedState)
  }

  public func transform(action: Observable<Action>) -> Observable<Action> {
    action
  }

  public func mutate(action: Action) -> Observable<Event> {
    .empty()
  }
  
  public func transform(event: Observable<Event>) -> Observable<Event> {
    transform(mutation: event)
  }
  
  public func transform(mutation: Observable<Event>) -> Observable<Event> {
    mutation
  }

  public func reduce(state: State, event: Event) -> State {
    reduce(state: state, mutation: event)
  }

  public func reduce(state: State, mutation: Event) -> State {
    state
  }

  public func transform(state: Observable<State>) -> Observable<State> {
    state
  }
}

extension Reactor where Action == Event {
  public func mutate(action: Action) -> Observable<Event> {
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
