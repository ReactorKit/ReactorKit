//
//  SignalTests.swift
//  ReactorKitTests
//
//  Created by 윤중현 on 2021/01/10.
//

import XCTest
import RxSwift
@testable import ReactorKit

final class SignalTests: XCTestCase {
  func testSignal() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedAlertMessages: [String] = []

    reactor.state
      .map(\.$alertMessage)
      .distinctAndCompactMapToValue()
      .subscribe(onNext: { alertMessage in
        receivedAlertMessages.append(alertMessage)
      })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.showAlert(message: "Hi"))
    reactor.action.onNext(.showAlert(message: "Hello"))
    reactor.action.onNext(.showAlert(message: "I'm tokijh"))
    reactor.action.onNext(.showAlert(message: "I'm tokijh"))
    reactor.action.onNext(.increaseCount) // no event of alertMessage
    reactor.action.onNext(.increaseCount) // no event of alertMessage
    reactor.action.onNext(.showAlert(message: "Hello"))
    reactor.action.onNext(.showAlert(message: "Hello"))

    // then
    XCTAssertEqual(receivedAlertMessages, [
      "Hi",
      "Hello",
      "I'm tokijh",
      "I'm tokijh",
      "Hello",
      "Hello",
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }

  func testRiseValueUpdatedCountWhenSetNewValue() {
    // given
    struct State {
      @Signal var value: Int = 0
    }

    var state = State()

    // when & then
    XCTAssertEqual(state.$value.valueUpdatedCount, 0)
    state.value = 10
    XCTAssertEqual(state.$value.valueUpdatedCount, 1)
    XCTAssertEqual(state.$value.valueUpdatedCount, 1) // same count because no new values are assigned.
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 2)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 3)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 4)
    XCTAssertEqual(state.$value.valueUpdatedCount, 4) // same count because no new values are assigned.
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 5)
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 6)
  }

  func testSet0WhenValueUpdatedCountIsOverflowed() {
    // given
    var signal = Signal<Int>(wrappedValue: 0)

    // make to full
    signal.valueUpdatedCount = UInt.max
    XCTAssertEqual(signal.valueUpdatedCount, UInt.max)

    // when & then
    signal.value = 1 // when valueUpdatedCount is overflowed
    XCTAssertEqual(signal.valueUpdatedCount, 0)

    signal.value = 2
    XCTAssertEqual(signal.valueUpdatedCount, 1)
  }

  func testDistinctAndMapToValue() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedAlertMessages: [String?] = []

    reactor.state
      .map(\.$alertMessage)
      .distinctAndMapToValue()
      .subscribe(onNext: { alertMessage in
        receivedAlertMessages.append(alertMessage)
      })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.showAlert(message: "1"))
    reactor.action.onNext(.increaseCount) // alert 에는 영향이 없음
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.showAlert(message: "2"))
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.increaseCount) // alert 에는 영향이 없음
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.showAlert(message: "3"))
    reactor.action.onNext(.showAlert(message: "3"))

    // then
    XCTAssertEqual(receivedAlertMessages, [
      nil, // initial value
      "1",
      nil,
      "2",
      nil,
      nil,
      "3",
      "3",
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }

  func testDistinctAndCompactMapToValue() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedAlertMessages: [String?] = []

    reactor.state
      .map(\.$alertMessage)
      .distinctAndCompactMapToValue()
      .subscribe(onNext: { alertMessage in
        receivedAlertMessages.append(alertMessage)
      })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.showAlert(message: "1"))
    reactor.action.onNext(.increaseCount) // no event of alertMessage
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.showAlert(message: "2"))
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.increaseCount) // no event of alertMessage
    reactor.action.onNext(.showAlert(message: nil))
    reactor.action.onNext(.showAlert(message: "3"))
    reactor.action.onNext(.showAlert(message: "3"))

    // then
    XCTAssertEqual(receivedAlertMessages, [
      // nil, // ignore nil
      "1",
      // nil, // ignore nil
      "2",
      // nil, // ignore nil
      // nil, // ignore nil
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
    @Signal var alertMessage: String?
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
