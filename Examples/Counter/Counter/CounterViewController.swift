//
//  CounterViewController.swift
//  Counter
//
//  Created by Suyeol Jeon on 02/05/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import UIKit

import ReactorKit
import RxCocoa
import RxSwift

// Conform to the protocol `View` then the property `self.reactor` will be available.
final class CounterViewController: UIViewController, View {
  @IBOutlet var decreaseButton: UIButton!
  @IBOutlet var increaseButton: UIButton!
  @IBOutlet var valueLabel: UILabel!
  var disposeBag = DisposeBag()

  // Called when the new value is assigned to `self.reactor`
  func bind(reactor: CounterViewReactor) {
    // Action
    increaseButton.rx.tap               // Tap event
      .map { Reactor.Action.increase }  // Convert to Action.increase
      .bind(to: reactor.action)         // Bind to reactor.action
      .disposed(by: disposeBag)

    decreaseButton.rx.tap
      .map { Reactor.Action.decrease }
      .bind(to: reactor.action)
      .disposed(by: disposeBag)

    // State
    reactor.state                    // State(value: 10)
      .map { $0.value }              // 10
      .map { "\($0)" }               // "10"
      .bind(to: valueLabel.rx.text)  // Bind to valueLabel
      .disposed(by: disposeBag)
  }
}

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
