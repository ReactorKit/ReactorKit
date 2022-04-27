//
//  CounterViewReactor.swift
//  Counter
//
//  Created by Suyeol Jeon on 07/09/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import ReactorKit
import RxSwift

final class CounterViewReactor: Reactor {
  // Action is an user interaction
  enum Action {
    case increase
    case decrease
  }

  // Mutate is a state manipulator which is not exposed to a view
  enum Mutation {
    case increaseValue
    case decreaseValue
    case setLoading(Bool)
    case setAlertMessage(String)
  }

  // State is a current view state
  struct State {
    var value: Int
    var isLoading: Bool
    @Pulse var alertMessage: String?
  }

  let initialState: State

  init() {
    self.initialState = State(
      value: 0, // start from 0
      isLoading: false
    )
  }

  // Action -> Mutation
  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increase:
      return Observable.concat([
        Observable.just(Mutation.setLoading(true)),
        Observable.just(Mutation.increaseValue).delay(.milliseconds(500), scheduler: MainScheduler.instance),
        Observable.just(Mutation.setLoading(false)),
        Observable.just(Mutation.setAlertMessage("increased!")),
      ])

    case .decrease:
      return Observable.concat([
        Observable.just(Mutation.setLoading(true)),
        Observable.just(Mutation.decreaseValue).delay(.milliseconds(500), scheduler: MainScheduler.instance),
        Observable.just(Mutation.setLoading(false)),
        Observable.just(Mutation.setAlertMessage("decreased!")),
      ])
    }
  }

  // Mutation -> State
  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .increaseValue:
      state.value += 1

    case .decreaseValue:
      state.value -= 1

    case let .setLoading(isLoading):
      state.isLoading = isLoading

    case let .setAlertMessage(message):
      state.alertMessage = message
    }
    return state
  }
}
