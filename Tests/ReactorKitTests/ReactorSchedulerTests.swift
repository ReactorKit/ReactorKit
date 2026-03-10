//
//  ReactorSchedulerTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest

import ReactorKit
@preconcurrency import RxSwift

@preconcurrency
final class ReactorSchedulerTests: XCTestCase {

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
}
