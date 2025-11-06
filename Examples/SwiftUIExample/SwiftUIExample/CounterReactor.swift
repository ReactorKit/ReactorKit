//
//  CounterReactor.swift
//  ReactorKitSwiftUIExample
//
//  Created by Kanghoon Oh on 2025.
//  Copyright © 2025 ReactorKit. All rights reserved.
//

import ReactorKit
import RxSwift

final class CounterReactor: Reactor {
  enum Action {
    case increase
    case decrease
    case reset
    case setValue(Int)
    case setLoading(Bool)
    case setText(String)
  }

  enum Mutation {
    case adjustValue(Int)
    case setValue(Int)
    case setLoading(Bool)
    case setText(String)
    case setAlertMessage(String?)
  }

  struct State {
    var value = 0
    var isLoading = false
    var text = ""
    var alertMessage: String?
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increase:
      guard currentState.value < 10 else {
        return .just(.setAlertMessage("Maximum value reached!"))
      }
      return .just(.adjustValue(1))

    case .decrease:
      guard currentState.value > -10 else {
        return .just(.setAlertMessage("Minimum value reached!"))
      }
      return .just(.adjustValue(-1))

    case .reset:
      return Observable.concat([
        .just(.setValue(0)),
        .just(.setAlertMessage("Counter reset")),
      ])

    case .setValue(let value):
      return .just(.setValue(value))

    case .setLoading(let isLoading):
      return .just(.setLoading(isLoading))

    case .setText(let text):
      return .just(.setText(text))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
    case .adjustValue(let amount):
      newState.value += amount

    case .setValue(let value):
      newState.value = value

    case .setLoading(let isLoading):
      newState.isLoading = isLoading

    case .setText(let text):
      newState.text = text

    case .setAlertMessage(let message):
      newState.alertMessage = message
    }

    return newState
  }
}
