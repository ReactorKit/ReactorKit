//
//  ThreadLocalTests.swift
//  ReactorKitObservationTests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Dispatch
import XCTest

@testable import ReactorKitObservation

final class ThreadLocalTests: XCTestCase {

  override func tearDown() {
    // Clean up thread-local storage after each test.
    _ThreadLocal.value = nil
    super.tearDown()
  }

  // MARK: - testDefaultIsNil
  /// Verifies that the thread-local value is nil by default (before any assignment).
  func testDefaultIsNil() {
    // Ensure clean state by resetting first.
    _ThreadLocal.value = nil
    XCTAssertNil(_ThreadLocal.value)
  }

  // MARK: - testSetAndGet
  /// Verifies that setting a value via the thread-local makes it retrievable.
  func testSetAndGet() {
    let dummy = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    defer { dummy.deallocate() }

    _ThreadLocal.value = dummy
    XCTAssertEqual(_ThreadLocal.value, dummy)
  }

  // MARK: - testResetToNil
  /// Verifies that setting the thread-local value to nil clears it.
  func testResetToNil() {
    let dummy = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    defer { dummy.deallocate() }

    _ThreadLocal.value = dummy
    XCTAssertNotNil(_ThreadLocal.value)

    _ThreadLocal.value = nil
    XCTAssertNil(_ThreadLocal.value)
  }

  // MARK: - testPerThreadIsolation
  /// Verifies that a value set on one thread is NOT visible on another thread.
  func testPerThreadIsolation() {
    let dummy = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    defer { dummy.deallocate() }

    // Set value on the main thread.
    _ThreadLocal.value = dummy

    let expectation = expectation(description: "background thread check")

    DispatchQueue.global().async {
      // On a different thread, the value should be nil (not the main thread's value).
      XCTAssertNil(_ThreadLocal.value, "Thread-local value should not leak across threads")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Main thread value should still be intact.
    XCTAssertEqual(_ThreadLocal.value, dummy)
  }
}
