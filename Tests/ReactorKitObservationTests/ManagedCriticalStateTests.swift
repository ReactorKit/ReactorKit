//
//  ManagedCriticalStateTests.swift
//  ReactorKitObservationTests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Dispatch
import XCTest

@testable import ReactorKitObservation

final class ManagedCriticalStateTests: XCTestCase {

  // MARK: - testInitialState
  /// Verifies that the state passed to init is readable via withCriticalRegion.
  func testInitialState() {
    let managed = _ManagedCriticalState<Int>(42)
    let value = managed.withCriticalRegion { state in
      state
    }
    XCTAssertEqual(value, 42)
  }

  // MARK: - testMutateState
  /// Verifies that mutations inside withCriticalRegion persist across calls.
  func testMutateState() {
    let managed = _ManagedCriticalState<Int>(0)

    managed.withCriticalRegion { state in
      state = 10
    }

    let value = managed.withCriticalRegion { state in
      state
    }
    XCTAssertEqual(value, 10)
  }

  // MARK: - testReturnValue
  /// Verifies that withCriticalRegion returns the closure's return value.
  func testReturnValue() {
    let managed = _ManagedCriticalState<String>("hello")

    let result = managed.withCriticalRegion { state -> Int in
      return state.count
    }
    XCTAssertEqual(result, 5)
  }

  // MARK: - testConcurrentAccess
  /// Verifies that concurrent access from multiple threads does not corrupt state.
  /// Increments a counter N times from multiple concurrent queues and checks the final count.
  func testConcurrentAccess() {
    let managed = _ManagedCriticalState<Int>(0)
    let iterations = 1000
    let queues = 4
    let group = DispatchGroup()
    let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

    for _ in 0..<queues {
      group.enter()
      concurrentQueue.async {
        for _ in 0..<iterations {
          managed.withCriticalRegion { state in
            state += 1
          }
        }
        group.leave()
      }
    }

    let expectation = expectation(description: "concurrent increments complete")
    group.notify(queue: .main) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 10.0)

    let finalValue = managed.withCriticalRegion { $0 }
    XCTAssertEqual(finalValue, iterations * queues)
  }
}
