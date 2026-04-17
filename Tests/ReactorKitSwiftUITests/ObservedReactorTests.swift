//
//  ObservedReactorTests.swift
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

// MARK: - Test Reactor

private final class TestReactor: Reactor {
  enum Action { case increment }
  enum Mutation { case increment }
  @ObservableState
  struct State { var count = 0 }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    .just(.increment)
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    state.count += 1
    return state
  }
}

// MARK: - Tests

@MainActor
final class ObservedReactorTests: XCTestCase {

  // MARK: - testStateUpdateThroughReactor
  /// Verifies that sending an action updates the observed reactor's state.
  func testStateUpdateThroughReactor() {
    let testReactor = TestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "state updated")
    let disposeBag = DisposeBag()

    // Observe the reactor's replay(1) state stream directly. Skipping the
    // initial replayed value and hopping onto MainScheduler guarantees the
    // assertion runs after ObservedReactor's own (earlier) subscriber has
    // written `_state`, so no fixed delay is needed.
    testReactor.state
      .skip(1)
      .take(1)
      .observe(on: MainScheduler.instance)
      .subscribe(onNext: { _ in
        MainActor.assumeIsolated {
          XCTAssertEqual(reactor.state.count, 1)
          expectation.fulfill()
        }
      })
      .disposed(by: disposeBag)

    reactor.send(TestReactor.Action.increment)

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testObservationTrackingDetectsStateAccess
  /// Verifies that reading state inside a tracking scope triggers onChange on state change.
  func testObservationTrackingDetectsStateAccess() {
    let testReactor = TestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "onChange triggered by state change")

    _withStateTracking {
      _ = reactor.state
    } onChange: {
      expectation.fulfill()
    }

    reactor.send(TestReactor.Action.increment)

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - testDynamicMemberLookupTriggersTracking
  /// Verifies that accessing state properties via dynamic member lookup (e.g., reactor.count)
  /// is tracked and triggers onChange on state change.
  func testDynamicMemberLookupTriggersTracking() {
    let testReactor = TestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let expectation = expectation(description: "onChange triggered via dynamicMemberLookup")

    _withStateTracking {
      _ = reactor.count
    } onChange: {
      expectation.fulfill()
    }

    reactor.send(TestReactor.Action.increment)

    wait(for: [expectation], timeout: 3.0)
  }
}
