//
//  Reactor.swift
//  Reactor
//
//  Created by Suyeol Jeon on 06/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import RxSwift

/// The base class of reactors.
open class Reactor<ActionType, MutationType, StateType>: ReactorType {
  public typealias Action = ActionType
  public typealias Mutation = MutationType
  public typealias State = StateType

  internal let actionSubject: PublishSubject<Action> = .init()
  open let action: AnyObserver<Action>

  open let initialState: State
  open private(set) var currentState: State
  open lazy private(set) var state: Observable<State> = self.createStateStream()

  public init(initialState: State) {
    self.action = self.actionSubject.asObserver()
    self.initialState = initialState
    self.currentState = initialState
  }

  internal func createStateStream() -> Observable<State> {
    let state = self.transform(action: self.actionSubject)
      .flatMap { [weak self] action -> Observable<Mutation> in
        guard let `self` = self else { return .empty() }
        return self.mutate(action: action)
      }
      .scan(self.initialState) { [weak self] state, mutation -> State in
        guard let `self` = self else { return state }
        return self.reduce(state: state, mutation: mutation)
      }
      .startWith(self.initialState)
      .retry() // ignore errors
      .shareReplay(1)
      .do(onNext: { [weak self] state in
        self?.currentState = state
      })
      .observeOn(MainScheduler.instance)
    return self.transform(state: state)
  }

  open func transform(action: Observable<Action>) -> Observable<Action> {
    return action
  }

  open func mutate(action: Action) -> Observable<Mutation> {
    return .empty()
  }

  open func reduce(state: State, mutation: Mutation) -> State {
    return state
  }

  open func transform(state: Observable<State>) -> Observable<State> {
    return state
  }
}
