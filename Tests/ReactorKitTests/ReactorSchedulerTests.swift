//
//  ReactorSchedulerTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest

import ReactorKit
import RxSwift

final class ReactorSchedulerTests: XCTestCase {

  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: Observable<Action>) -> Observable<Action> {
        return action
      }
    }

    let reactor = SimpleReactor()
    var states: [Observable<SimpleReactor.State>] = []
    let lock = NSLock()
    let expectation = XCTestExpectation()

    for _ in 0..<100 {
      DispatchQueue.global().async {
        let state = reactor.state
        lock.lock()
        states.append(state)
        lock.unlock()

        if states.count == 100 {
          expectation.fulfill()
        }
      }
    }

    XCTWaiter().wait(for: [expectation], timeout: 10)

    XCTAssertGreaterThan(states.count, 0)
    for state in states {
      XCTAssertTrue(state === states.first)
    }
  }
}
