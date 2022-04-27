//
//  Reactor+PulseTests.swift
//  ReactorKit
//
//  Created by 윤중현 on 2021/03/31.
//

import XCTest
import RxSwift
@testable import ReactorKit

final class Reactor_PulseTests: XCTestCase {
  func testPulse() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedAlertMessages: [String] = []

    reactor.pulse(\.$alertMessage)
      .compactMap { $0 }
      .subscribe(onNext: { alertMessage in
        receivedAlertMessages.append(alertMessage)
      })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount)           // ignore
    reactor.action.onNext(.showAlert(message: nil)) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'
    reactor.action.onNext(.showAlert(message: nil)) // ignore
    reactor.action.onNext(.increaseCount)           // ignore
    reactor.action.onNext(.showAlert(message: nil)) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedAlertMessages, [
      "1",
      "2",
      "3",
      "3",
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
}

private final class TestReactor: Reactor {
  enum Action {
    case showAlert(message: String?)
    case increaseCount
  }

  enum Mutation {
    case setAlertMessage(String?)
    case increaseCount
  }

  struct State {
    @Pulse var alertMessage: String?
    var count: Int = 0
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .showAlert(message):
      return Observable.just(Mutation.setAlertMessage(message))

    case .increaseCount:
      return Observable.just(Mutation.increaseCount)
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
    case let .setAlertMessage(alertMessage):
      newState.alertMessage = alertMessage

    case .increaseCount:
      newState.count += 1
    }

    return newState
  }
}
