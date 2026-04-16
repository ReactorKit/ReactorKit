//
//  ObservedReactorObservableStateTests.swift
//  ReactorKitSwiftUITests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import XCTest

import ReactorKit
import ReactorKitObservation
@preconcurrency import RxSwift
@testable import ReactorKitObservation
@testable import ReactorKitSwiftUI

// MARK: - Test Reactor with ObservableState

private final class ObservableStateReactor: Reactor {
  enum Action {
    case increment
    case setName(String)
    case setLoading(Bool)
  }

  enum Mutation {
    case increment
    case setName(String)
    case setLoading(Bool)
  }

  @ObservableState
  struct State {
    var count = 0
    var name = ""
    var isLoading = false
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increment:
      .just(.increment)
    case .setName(let name):
      .just(.setName(name))
    case .setLoading(let loading):
      .just(.setLoading(loading))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .increment:
      state.count += 1
    case .setName(let name):
      state.name = name
    case .setLoading(let loading):
      state.isLoading = loading
    }
    return state
  }
}

// MARK: - Test Reactor with @ObservableStateIgnored

private final class IgnoredPropertyReactor: Reactor {
  enum Action {
    case increment
    case updateCache(String)
  }

  enum Mutation {
    case increment
    case updateCache(String)
  }

  @ObservableState
  struct State {
    var count = 0
    @ObservableStateIgnored
    var cache = [String]()
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increment:
      .just(.increment)
    case .updateCache(let value):
      .just(.updateCache(value))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .increment:
      state.count += 1
    case .updateCache(let value):
      state.cache.append(value)
    }
    return state
  }
}

// MARK: - Test Reactor with @Pulse

private final class PulseReactor: Reactor {
  enum Action { case sendAlert(String) }
  enum Mutation { case setAlert(String) }

  @ObservableState
  struct State {
    var count = 0
    @Pulse var alertMessage: String?
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .sendAlert(let msg):
      .just(.setAlert(msg))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .setAlert(let msg):
      state.alertMessage = msg
    }
    return state
  }
}

// MARK: - Integration Tests

@MainActor
final class ObservedReactorObservableStateTests: XCTestCase {

  // MARK: - testDynamicMemberLookupWithObservableState

  /// Verifies that accessing individual properties through dynamicMemberLookup
  /// works correctly when State conforms to ObservableState.
  func testDynamicMemberLookupWithObservableState() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    XCTAssertEqual(reactor.count, 0)
    XCTAssertEqual(reactor.name, "")
    XCTAssertFalse(reactor.isLoading)
  }

  // MARK: - testStateUpdateWithObservableState

  /// Verifies that sending an action updates the observed reactor's state
  /// when State conforms to ObservableState.
  func testStateUpdateWithObservableState() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "state updated")

    reactor.send(.increment)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      MainActor.assumeIsolated {
        XCTAssertEqual(reactor.count, 1)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testMultiplePropertyUpdatesWithObservableState

  /// Verifies that multiple property updates work correctly.
  func testMultiplePropertyUpdatesWithObservableState() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "all state updated")

    reactor.send(.increment)
    reactor.send(.setName("hello"))
    reactor.send(.setLoading(true))

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      MainActor.assumeIsolated {
        XCTAssertEqual(reactor.count, 1)
        XCTAssertEqual(reactor.name, "hello")
        XCTAssertTrue(reactor.isLoading)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testObservationTrackingWithObservableState

  /// Verifies that observation tracking detects state changes when
  /// State conforms to ObservableState.
  func testObservationTrackingWithObservableState() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "onChange triggered")

    _withStateTracking {
      _ = reactor.state
    } onChange: {
      expectation.fulfill()
    }

    reactor.send(.increment)

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testDynamicMemberLookupWithPerPropertyTracking

  /// When State conforms to ObservableState, the constrained dynamicMemberLookup
  /// subscript registers per-property access via `accessAnyKeyPath`. When the
  /// accessed property changes, onChange fires through per-property tracking.
  func testDynamicMemberLookupWithPerPropertyTracking() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let onChangeCalled = expectation(description: "per-property onChange should fire")

    _withStateTracking {
      // This goes through the ObservableState-constrained subscript,
      // which registers per-property access via accessAnyKeyPath.
      _ = reactor.count
    } onChange: {
      onChangeCalled.fulfill()
    }

    reactor.send(.increment)

    wait(for: [onChangeCalled], timeout: 3.0)
  }

  // MARK: - testSendAction

  /// Verifies that the send method correctly dispatches actions for ObservableState reactors.
  func testSendAction() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "name updated via send")

    reactor.send(.setName("world"))

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      MainActor.assumeIsolated {
        XCTAssertEqual(reactor.name, "world")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testInitialStateValues

  /// Verifies that the ObservedReactor starts with the reactor's initial state.
  func testInitialStateValues() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    XCTAssertEqual(reactor.state.count, 0)
    XCTAssertEqual(reactor.state.name, "")
    XCTAssertFalse(reactor.state.isLoading)
  }

  // MARK: - testSequentialActions

  /// Verifies that sequential actions are processed in order.
  func testSequentialActions() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "sequential actions processed")

    reactor.send(.increment)
    reactor.send(.increment)
    reactor.send(.increment)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      MainActor.assumeIsolated {
        XCTAssertEqual(reactor.count, 3)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testPerPropertyScopingIsolatesReaders

  /// Per-property scoping: reading only `\.count` does NOT invalidate when
  /// an unrelated property (`\.isLoading`) changes. This is the defining
  /// property of `@ObservableState`.
  func testPerPropertyScopingIsolatesReaders() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    final class Flag: @unchecked Sendable { var value = false }
    let countObserverFired = Flag()

    _withStateTracking {
      _ = reactor.count
    } onChange: {
      countObserverFired.value = true
    }

    reactor.send(.setLoading(true)) // Changes \.isLoading, not \.count

    let spun = expectation(description: "runloop spun")
    DispatchQueue.main.async { spun.fulfill() }
    wait(for: [spun], timeout: 1.0)

    XCTAssertFalse(
      countObserverFired.value,
      "observer reading only \\.count must not be invalidated when \\.isLoading changes"
    )
  }

  // MARK: - testPerPropertyScopingFiresForMatchingReader

  /// The flip side: an observer reading `\.count` DOES fire when `\.count`
  /// changes. Per-property scoping is real, not just suppression.
  func testPerPropertyScopingFiresForMatchingReader() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let countChanged = expectation(description: "count observer fired")

    _withStateTracking {
      _ = reactor.count
    } onChange: {
      countChanged.fulfill()
    }

    reactor.send(.increment)
    wait(for: [countChanged], timeout: 3.0)
  }

  // MARK: - testPerPropertyScopingAcrossMultipleObservers

  /// Multiple independent observers — only the one tracking the written
  /// property is invalidated.
  func testPerPropertyScopingAcrossMultipleObservers() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let countChanged = expectation(description: "count observer fired")
    final class Flag: @unchecked Sendable { var value = false }
    let nameObserverFired = Flag()

    // Observer A: watches count
    _withStateTracking {
      _ = reactor.count
    } onChange: {
      countChanged.fulfill()
    }

    // Observer B: watches name
    _withStateTracking {
      _ = reactor.name
    } onChange: {
      nameObserverFired.value = true
    }

    // Increment count → only count observer fires (per-property scoping)
    reactor.send(.increment)
    wait(for: [countChanged], timeout: 3.0)

    XCTAssertFalse(
      nameObserverFired.value,
      "observer watching \\.name must not fire when \\.count changes"
    )
  }

  // MARK: - testIgnoredPropertyDoesNotInvalidatePerPropertyReaders

  /// `@ObservableStateIgnored` properties do not record per-property
  /// mutations, so per-property readers are NOT invalidated when an ignored
  /// property changes. (Coarse `reactor.state` readers still are — see
  /// `testObservationTrackingWithObservableState`.)
  func testIgnoredPropertyDoesNotInvalidatePerPropertyReaders() {
    let testReactor = IgnoredPropertyReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    final class Flag: @unchecked Sendable { var value = false }
    let countObserverFired = Flag()

    _withStateTracking {
      _ = reactor.count
    } onChange: {
      countObserverFired.value = true
    }

    reactor.send(.updateCache("test"))

    let spun = expectation(description: "runloop spun")
    DispatchQueue.main.async { spun.fulfill() }
    wait(for: [spun], timeout: 1.0)

    XCTAssertFalse(
      countObserverFired.value,
      "per-property reader of \\.count must not fire when an @ObservableStateIgnored property changes"
    )
  }

  // MARK: - testPulseReactorStateCompiles

  /// P0: @Pulse reactor compiles and works
  func testPulseReactorStateCompiles() {
    let testReactor = PulseReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    XCTAssertEqual(reactor.count, 0)
    XCTAssertNil(reactor.state.alertMessage)
  }

  // MARK: - testBindingWithPerPropertyTracking

  /// P1: Binding works with per-property tracking
  func testBindingWithPerPropertyTracking() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let binding = reactor.binding(
      get: \.count,
      send: { _ in .increment }
    )
    XCTAssertEqual(binding.wrappedValue, 0)
  }

  // MARK: - testMultipleRapidStateChangesTracked

  /// P1: Rapid state changes
  func testMultipleRapidStateChangesTracked() {
    let testReactor = ObservableStateReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "final count is 100")

    for _ in 0..<100 {
      reactor.send(.increment)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      MainActor.assumeIsolated {
        XCTAssertEqual(reactor.count, 100)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }
}
