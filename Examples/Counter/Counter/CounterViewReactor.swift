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

  // Mutate is a state manipulator
  enum Mutation {
    case increaseValue
    case decreaseValue
  }

  // State is a current view state
  struct State {
    var value: Int
  }

  let initialState = State(value: 0) // start from 0

  // Action -> Mutation
  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increase:
      return Observable.just(Mutation.increaseValue) // Action.increase -> Mutation.increaseValue
    case .decrease:
      return Observable.just(Mutation.decreaseValue) // Action.decrease -> Mutation.decreaseValue
    }
  }

  // Mutation -> State
  func reduce(state: State, mutation: Mutation) -> State {
    switch mutation {
    case .increaseValue:
      return State(value: state.value + 1)
    case .decreaseValue:
      return State(value: state.value - 1)
    }
  }
}
