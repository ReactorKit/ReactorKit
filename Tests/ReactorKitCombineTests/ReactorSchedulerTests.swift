//
//  ReactorSchedulerTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/06.
//

import XCTest

import Combine
import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AnyPublisher: Equatable {
  public static func == (lhs: AnyPublisher<Output, Failure>, rhs: AnyPublisher<Output, Failure>) -> Bool {
    Swift.print(lhs, ObjectIdentifier(lhs as AnyObject).hashValue, rhs, ObjectIdentifier(rhs as AnyObject).hashValue)
    return ObjectIdentifier(lhs as AnyObject).hashValue == ObjectIdentifier(rhs as AnyObject).hashValue
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ReactorSchedulerTests: XCTestCase {
  // TODO: How can I test same AnyPublisher
  /*
  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: AnyPublisher<Action, Never>) -> AnyPublisher<Action, Never> {
        sleep(5)
        return action
      }
    }

    let reactor = SimpleReactor()
    var states: [AnyPublisher<SimpleReactor.State, Never>] = []
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
  */

  func testScheduler() {
    final class SimpleReactor: Reactor {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var reductionThreads: [Thread] = []
      }

      let initialState: State = State()
      let scheduler = DispatchQueue.global()

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        let currentThread = Thread.current
        newState.reductionThreads.append(currentThread)
        return newState
      }
    }

    let reactor = SimpleReactor()
    var cancellables: Set<AnyCancellable> = []

    var observationThreads: [Thread] = []

    var isExecuted = false

    DispatchQueue.global().async {
      let currentThread = Thread.current

      reactor.state
        .sink(receiveValue: { _ in
          let currentThread = Thread.current
          observationThreads.append(currentThread)
        })
        .store(in: &cancellables)

      for _ in 0..<100 {
        reactor.action.send(Void())
      }

      XCTWaiter().wait(for: [XCTestExpectation()], timeout: 1)

      let reductionThreads = reactor.currentState.reductionThreads
      XCTAssertEqual(reductionThreads.count, 100)
      for thread in reductionThreads {
        XCTAssertNotEqual(thread, currentThread)
      }

      XCTAssertEqual(observationThreads.count, 101) // +1 for initial state

      // initial state is observed on the same thread with the one where the state stream is created.
      XCTAssertEqual(observationThreads[0], currentThread)

      // other states are observed on the specified thread.
      for thread in observationThreads[1...] {
        XCTAssertNotEqual(thread, currentThread)
      }

      isExecuted = true
    }

    XCTWaiter().wait(for: [XCTestExpectation()], timeout: 1.5)
    XCTAssertTrue(isExecuted)
  }
}

