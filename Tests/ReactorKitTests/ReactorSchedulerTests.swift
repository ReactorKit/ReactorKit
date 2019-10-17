//
//  ReactorSchedulerTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import ReactorKit
import RxSwift
import XCTest

final class ReactorSchedulerTests: XCTestCase {
  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: Observable<Action>) -> Observable<Action> {
        sleep(5)
        return action
      }
    }

    let reactor = SimpleReactor()
    var states: [Observable<SimpleReactor.State>] = []
    let lock = NSLock()

    for _ in 0..<100 {
      DispatchQueue.global().async {
        let state = reactor.state
        lock.lock()
        states.append(state)
        lock.unlock()
      }
    }

    XCTWaiter().wait(for: [XCTestExpectation()], timeout: 10)

    XCTAssertGreaterThan(states.count, 0)
    for state in states {
      XCTAssertTrue(state === states.first)
    }
  }
}
