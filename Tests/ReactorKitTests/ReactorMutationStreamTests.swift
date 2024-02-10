//
//  ReactorMutationStreamTests.swift
//  ReactorKit
//
//  Created by 김동현 on 2024/02/11.
//

import XCTest

import RxSwift
@testable import ReactorKit

final class ReactorMutationStreamTests: XCTestCase {
  func testReceiveAllMutationsCorrectly() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedMutations: [TestReactor.Mutation] = []
    
    reactor.mutation
      .subscribe(onNext: { receivedMutations.append($0) })
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
    XCTAssertEqual(receivedMutations, [
      TestReactor.Mutation.alertMessageDidChange("1"),
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("2"),
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("3"),
      TestReactor.Mutation.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
  
  func testReceiveAllMutationsPublishedAfterSubscribe() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedMutations: [TestReactor.Mutation] = []

    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'

    reactor.mutation
      .subscribe(onNext: { receivedMutations.append($0) })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedMutations, [
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("3"),
      TestReactor.Mutation.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(reactor.currentState.count, 2)
  }
  
  func testMultipleSubscriptionShouldReceiveAllMutationsPublishedAfterSubscribe() {
    // given
    let reactor = TestReactor()
    let disposeBag = DisposeBag()
    var receivedMutations1: [TestReactor.Mutation] = []
    var receivedMutations2: [TestReactor.Mutation] = []
    var receivedMutations3: [TestReactor.Mutation] = []
    
    reactor.mutation
      .subscribe(onNext: { receivedMutations1.append($0) })
      .disposed(by: disposeBag)
    
    reactor.action.onNext(.showAlert(message: "1")) // alert '1'
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "2")) // alert '2'
    
    reactor.mutation
      .subscribe(onNext: { receivedMutations2.append($0) })
      .disposed(by: disposeBag)
    
    reactor.mutation
      .subscribe(onNext: { receivedMutations3.append($0) })
      .disposed(by: disposeBag)

    // when
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.increaseCount) // ignore
    reactor.action.onNext(.closeAlert) // ignore
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'
    reactor.action.onNext(.showAlert(message: "3")) // alert '3'

    // then
    XCTAssertEqual(receivedMutations1, [
      TestReactor.Mutation.alertMessageDidChange("1"),
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("2"),
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("3"),
      TestReactor.Mutation.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(receivedMutations2, [
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("3"),
      TestReactor.Mutation.alertMessageDidChange("3"),
    ])
    XCTAssertEqual(receivedMutations3, [
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.countDidIncrease,
      TestReactor.Mutation.alertMessageDidClose,
      TestReactor.Mutation.alertMessageDidChange("3"),
      TestReactor.Mutation.alertMessageDidChange("3"),
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
  
  enum Mutation: Equatable {
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
      return Observable.just(Mutation.alertMessageDidClose)

    case .showAlert(let message):
      return Observable.just(Mutation.alertMessageDidChange(message))

    case .increaseCount:
      return Observable.just(Mutation.countDidIncrease)
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
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
