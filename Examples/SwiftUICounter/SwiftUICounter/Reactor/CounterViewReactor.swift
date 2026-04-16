//
//  CounterViewReactor.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import ReactorKit
import ReactorKitObservation
import RxSwift

final class CounterViewReactor: Reactor {

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case increase
    case decrease
    case toggleCounterVisible
  }

  enum Mutation {
    case binding(BindingAction<State>)
    case increaseValue
    case decreaseValue
    case setCounterVisible(Bool)
    case setLoading(Bool)
  }

  @ObservableState
  struct State {
    var count: Int = 0
    var text: String = ""
    var isCounterVisible: Bool = true
    var isLoading: Bool = false
    var showAlert: Bool = false
    var alertMessage: String?
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .binding(let bindingAction):
      return .just(.binding(bindingAction))

    case .increase:
      return Observable.concat([
        .just(.setLoading(true)),
        Observable.just(.increaseValue)
          .delay(.milliseconds(300), scheduler: MainScheduler.instance),
      ])

    case .decrease:
      return Observable.concat([
        .just(.setLoading(true)),
        Observable.just(.decreaseValue)
          .delay(.milliseconds(300), scheduler: MainScheduler.instance),
      ])

    case .toggleCounterVisible:
      return .just(.setCounterVisible(!currentState.isCounterVisible))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .binding(let bindingAction):
      bindingAction.apply(to: &state)
    case .increaseValue:
      state.count += 1
      state.isLoading = false
      state.alertMessage = "Count: \(state.count)"
      state.showAlert = true
    case .decreaseValue:
      state.count -= 1
      state.isLoading = false
      state.alertMessage = "Count: \(state.count)"
      state.showAlert = true
    case let .setCounterVisible(isVisible):
      state.isCounterVisible = isVisible
    case let .setLoading(isLoading):
      state.isLoading = isLoading
    }
    return state
  }
}
