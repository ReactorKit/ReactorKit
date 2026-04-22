//
//  ReactorDispatchTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest

import ReactorKit
@preconcurrency import RxSwift

@preconcurrency
final class ReactorDispatchTests: XCTestCase {

  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: Observable<Action>) -> Observable<Action> {
        return action
      }
    }

    final class StateBox: @unchecked Sendable {
      var value: [Observable<SimpleReactor.State>] = []
    }

    let reactor = SimpleReactor()
    let states = StateBox()
    let lock = NSLock()
    let expectation = XCTestExpectation()

    for _ in 0..<100 {
      DispatchQueue.global().async {
        let state = reactor.state
        lock.lock()
        states.value.append(state)
        let count = states.value.count
        lock.unlock()

        if count == 100 {
          expectation.fulfill()
        }
      }
    }

    XCTWaiter().wait(for: [expectation], timeout: 10)

    XCTAssertGreaterThan(states.value.count, 0)
    for state in states.value {
      XCTAssertTrue(state === states.value.first)
    }
  }

  /// Verifies the DEBUG action-dispatch contract check does not block or
  /// crash the pipeline when an action is dispatched from a non-main thread.
  /// The `os_log` fault emission itself is observable in Xcode's console;
  /// this test only guarantees the check is non-fatal and preserves
  /// correctness so the warning surfaces a real misuse rather than a
  /// regression.
  func testActionDispatchContractCheckIsNonFatal() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var count = 0
      }

      let initialState = State()

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        newState.count += 1
        return newState
      }
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()
    let expectation = XCTestExpectation()

    reactor.state
      .skip(1) // initial state
      .subscribe(onNext: { state in
        if state.count == 1 {
          expectation.fulfill()
        }
      })
      .disposed(by: disposeBag)

    DispatchQueue.global().async {
      reactor.action.onNext(Void())
    }

    XCTWaiter().wait(for: [expectation], timeout: 5)
    XCTAssertEqual(reactor.currentState.count, 1)
  }
}
