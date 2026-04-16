//
//  BackportRegistrarTests.swift
//  ReactorKitObservationTests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import XCTest
@testable import ReactorKitObservation

// MARK: - Test Subject

/// A simple observable class used as the subject for registrar tests.
private final class TestSubject: @unchecked Sendable {
  var _value = 0
  var value: Int {
    get {
      registrar.access(self, keyPath: \.value)
      return _value
    }
    set {
      registrar.withMutation(of: self, keyPath: \.value) {
        _value = newValue
      }
    }
  }

  var _name = ""
  var name: String {
    get {
      registrar.access(self, keyPath: \.name)
      return _name
    }
    set {
      registrar.withMutation(of: self, keyPath: \.name) {
        _name = newValue
      }
    }
  }

  let registrar = BackportRegistrar()
}

// MARK: - Tests

final class BackportRegistrarTests: XCTestCase {

  // MARK: - testAccessRecordedDuringTracking
  /// Verifies that reading a tracked property inside _withStateTracking records the access
  /// and triggers onChange when the property is later mutated.
  func testAccessRecordedDuringTracking() {
    let subject = TestSubject()
    let expectation = expectation(description: "onChange called")

    _withStateTracking {
      // Reading value records access on \.value.
      _ = subject.value
    } onChange: {
      expectation.fulfill()
    }

    // Mutating the tracked property should fire onChange.
    subject.value = 99

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - testAccessOutsideTrackingIsNoOp
  /// Verifies that calling access() outside any tracking scope does not crash.
  func testAccessOutsideTrackingIsNoOp() {
    let subject = TestSubject()
    // This should not crash or have any side effects.
    subject.registrar.access(subject, keyPath: \.value)
  }

  // MARK: - testWillSetTriggersOnChange
  /// Verifies that after _withStateTracking records an access,
  /// calling willSet on the same keyPath triggers the onChange callback.
  func testWillSetTriggersOnChange() {
    let subject = TestSubject()
    let expectation = expectation(description: "onChange fires on willSet")

    _withStateTracking {
      _ = subject.value
    } onChange: {
      expectation.fulfill()
    }

    // Directly calling willSet should trigger onChange.
    subject.registrar.willSet(subject, keyPath: \.value)

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - testOneShotBehavior
  /// Verifies that onChange fires only once (one-shot semantics).
  /// Subsequent willSet calls after the first should NOT trigger onChange again.
  func testOneShotBehavior() {
    let subject = TestSubject()
    let callCount = _ManagedCriticalState<Int>(0)

    let expectation = expectation(description: "onChange fires once")

    _withStateTracking {
      _ = subject.value
    } onChange: {
      callCount.withCriticalRegion { $0 += 1 }
      expectation.fulfill()
    }

    // First mutation triggers onChange.
    subject.value = 1
    wait(for: [expectation], timeout: 2.0)

    // Second mutation should NOT trigger onChange again.
    subject.value = 2

    // Give a small window for any erroneous second call.
    let noSecondCall = self.expectation(description: "no second onChange")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      noSecondCall.fulfill()
    }
    wait(for: [noSecondCall], timeout: 1.0)

    XCTAssertEqual(callCount.withCriticalRegion { $0 }, 1, "onChange should fire exactly once (one-shot)")
  }

  // MARK: - testWillSetOnUntrackedKeyPathDoesNotTrigger
  /// Verifies that willSet on a keyPath NOT accessed during tracking does NOT fire onChange.
  func testWillSetOnUntrackedKeyPathDoesNotTrigger() {
    let subject = TestSubject()

    let onChangeCalled = expectation(description: "onChange should not be called")
    onChangeCalled.isInverted = true

    _withStateTracking {
      // Only access \.value, NOT \.name.
      _ = subject.value
    } onChange: {
      onChangeCalled.fulfill()
    }

    // Mutating \.name (which was not tracked) should NOT fire onChange.
    subject.name = "hello"

    wait(for: [onChangeCalled], timeout: 0.5)
  }

  // MARK: - testMultipleTrackingScopes
  /// Verifies that two separate _withStateTracking scopes each get their own callback.
  func testMultipleTrackingScopes() {
    let subject = TestSubject()

    let expectation1 = expectation(description: "scope 1 onChange")
    let expectation2 = expectation(description: "scope 2 onChange")

    _withStateTracking {
      _ = subject.value
    } onChange: {
      expectation1.fulfill()
    }

    _withStateTracking {
      _ = subject.name
    } onChange: {
      expectation2.fulfill()
    }

    // Trigger both tracked properties.
    subject.value = 10
    subject.name = "world"

    wait(for: [expectation1, expectation2], timeout: 2.0)
  }

  // MARK: - testOneShotAcrossMultipleSubjects
  /// Verifies one-shot semantics when tracking properties from TWO different subjects
  /// in the same scope. After the first subject fires, the second should be cancelled
  /// and not fire onChange again.
  func testOneShotAcrossMultipleSubjects() {
    let subject1 = TestSubject()
    let subject2 = TestSubject()
    let callCount = _ManagedCriticalState<Int>(0)

    let expectation = expectation(description: "onChange fires once")

    _withStateTracking {
      _ = subject1.value
      _ = subject2.value
    } onChange: {
      callCount.withCriticalRegion { $0 += 1 }
      expectation.fulfill()
    }

    // First subject mutation triggers onChange.
    subject1.value = 1
    wait(for: [expectation], timeout: 2.0)

    // Second subject mutation should NOT fire onChange (one-shot across subjects).
    subject2.value = 2

    let noSecondCall = self.expectation(description: "no second onChange")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      noSecondCall.fulfill()
    }
    wait(for: [noSecondCall], timeout: 1.0)

    XCTAssertEqual(callCount.withCriticalRegion { $0 }, 1, "onChange should fire exactly once across multiple subjects")
  }

  // MARK: - testConcurrentWillSetDuringInstallTracking
  /// Verifies that if willSet fires concurrently during observer registration
  /// (e.g., from a background thread), onChange still fires exactly once and
  /// all observers are properly cleaned up.
  func testConcurrentWillSetDuringInstallTracking() {
    let subject1 = TestSubject()
    let subject2 = TestSubject()
    let callCount = _ManagedCriticalState<Int>(0)

    let expectation = expectation(description: "onChange fires")

    _withStateTracking {
      _ = subject1.value
      _ = subject2.value
    } onChange: {
      callCount.withCriticalRegion { $0 += 1 }
      expectation.fulfill()
    }

    // Trigger from background thread to simulate race with installTracking.
    DispatchQueue.global().async {
      subject1.value = 42
    }

    wait(for: [expectation], timeout: 2.0)

    // Give time for any spurious second call.
    subject2.value = 99
    let noSecondCall = self.expectation(description: "no second onChange")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      noSecondCall.fulfill()
    }
    wait(for: [noSecondCall], timeout: 1.0)

    XCTAssertEqual(callCount.withCriticalRegion { $0 }, 1)
  }

  // MARK: - testNestedTracking
  /// Verifies that nested _withStateTracking merges access into the parent scope,
  /// so the outer onChange fires when a property accessed in the inner scope changes.
  func testNestedTracking() {
    let subject = TestSubject()
    let expectation = expectation(description: "outer onChange fires for inner access")

    _withStateTracking {
      // Outer scope accesses \.value.
      _ = subject.value

      _withStateTracking {
        // Inner scope accesses \.name.
        _ = subject.name
      } onChange: {
        // Inner scope onChange — not what we're testing here.
      }
    } onChange: {
      expectation.fulfill()
    }

    // Changing \.name (accessed in inner scope) should trigger outer onChange
    // if accesses are merged into the parent scope.
    subject.name = "nested"

    wait(for: [expectation], timeout: 2.0)
  }
}
