//
//  Reactor+PulseTests.swift
//  ReactorKit
//
//  Created by 김동현 on 2024/02/11.
//

import XCTest

import RxSwift
@testable import ReactorKit

final class Reactor_EventTests: XCTestCase {
  func testReceiveAllEventsCorrectly() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedEvents: [TestReactor.Event] = []
    
    reactor.event
      .subscribe(onNext: { receivedEvents.append($0) })
      .disposed(by: disposeBag)
    
    // when
    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedEvents, [
      TestReactor.Event.alertMessageDidChange("1"),
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("2"),
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("3"),
      TestReactor.Event.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
  
  func testReceiveAllEventsPublishedAfterSubscribe() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedEvents: [TestReactor.Event] = []

    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'

    reactor.event
      .subscribe(onNext: { receivedEvents.append($0) })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedEvents, [
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("3"),
      TestReactor.Event.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
  
  func testMultipleSubscriptionShouldReceiveAllEventsPublishedAfterSubscribe() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedEvents1: [TestReactor.Event] = []
    var receivedEvents2: [TestReactor.Event] = []
    var receivedEvents3: [TestReactor.Event] = []
    
    reactor.event
      .subscribe(onNext: { receivedEvents1.append($0) })
      .disposed(by: disposeBag)
    
    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'
    
    reactor.event
      .subscribe(onNext: { receivedEvents2.append($0) })
      .disposed(by: disposeBag)
    
    reactor.event
      .subscribe(onNext: { receivedEvents3.append($0) })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedEvents1, [
      TestReactor.Event.alertMessageDidChange("1"),
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("2"),
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("3"),
      TestReactor.Event.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(receivedEvents2, [
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("3"),
      TestReactor.Event.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(receivedEvents3, [
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.countDidIncrease,
      TestReactor.Event.alertMessageDidClose,
      TestReactor.Event.alertMessageDidChange("3"),
      TestReactor.Event.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
}

private final class TestReactor: Reactor {
  enum Action {
    case closeAlert
    case showAlert(message: String)
    case increaseCount
  }
  
  enum Event: Equatable {
    case alertMessageDidChange(String)
    case alertMessageDidClose
    case countDidIncrease
  }
  
  struct State {
    var count = 0
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .closeAlert:
      return Observable.just(Event.alertMessageDidClose)

    case .showAlert(let message):
      return Observable.just(Event.alertMessageDidChange(message))

    case .increaseCount:
      return Observable.just(Event.countDidIncrease)
    }
  }

  func reduce(state: State, event: Event) -> State {
    var newState = state

    switch event {
    case .alertMessageDidClose:
      // no-op
      break
      
    case .alertMessageDidChange:
      // no-op
      break

    case .countDidIncrease:
      newState.count += 1
    }

    return newState
  }
}
