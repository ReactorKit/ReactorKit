//
//  BindableTests.swift
//  ReactorKitSwiftUITests
//
//  Created by Kanghoon Oh on 4/12/26.
//

#if canImport(Observation)
import Observation
#endif
import SwiftUI
import XCTest

import ReactorKit
import ReactorKitObservation
@preconcurrency import RxSwift
@testable import ReactorKitObservation
@testable import ReactorKitSwiftUI

// MARK: - Test reactor with BindableAction

private final class BindableTestReactor: Reactor {
  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case submit
  }

  enum Mutation {
    case binding(BindingAction<State>)
    case submitted
  }

  @ObservableState
  struct State {
    var text = ""
    var isEnabled = false
    var count = 0
  }

  let initialState = State()

  /// Records every action mutate observed, for assertions.
  var observedActions = [Action]()

  func mutate(action: Action) -> Observable<Mutation> {
    observedActions.append(action)
    switch action {
    case .binding(let a):
      return .just(.binding(a))
    case .submit:
      return .just(.submitted)
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .binding(let a):
      a.apply(to: &state)
    case .submitted:
      state.count += 1
    }
    return state
  }
}

// MARK: - Test reactor that uppercases bindings (for snap-back behavior)

private final class UppercasingReactor: Reactor {
  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  enum Mutation {
    case binding(BindingAction<State>)
  }

  @ObservableState
  struct State {
    var text = ""
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .binding(let a):
      .just(.binding(a))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var state = state
    switch mutation {
    case .binding(let a):
      a.apply(to: &state)
      state.text = state.text.uppercased()
    }
    return state
  }
}

// MARK: - BindingAction value-type tests

final class BindingActionTests: XCTestCase {

  func testApplyAssignsValue() {
    var state = BindableTestReactor.State()
    let action = BindingAction.set(\BindableTestReactor.State.text, "hi")
    action.apply(to: &state)
    XCTAssertEqual(state.text, "hi")
  }

  func testPatternMatchOperator() {
    let action = BindingAction.set(\BindableTestReactor.State.text, "x")
    XCTAssertTrue(\BindableTestReactor.State.text ~= action)
    XCTAssertFalse(\BindableTestReactor.State.count ~= action)
  }

  func testEqualitySameKeyPathSameValue() {
    let a = BindingAction.set(\BindableTestReactor.State.text, "hi")
    let b = BindingAction.set(\BindableTestReactor.State.text, "hi")
    XCTAssertEqual(a, b)
  }

  func testInequalityDifferentValue() {
    let a = BindingAction.set(\BindableTestReactor.State.text, "hi")
    let b = BindingAction.set(\BindableTestReactor.State.text, "bye")
    XCTAssertNotEqual(a, b)
  }

  func testInequalityDifferentKeyPath() {
    let a = BindingAction.set(\BindableTestReactor.State.text, "hi")
    let b = BindingAction.set(\BindableTestReactor.State.count, 0)
    XCTAssertNotEqual(a, b)
  }

  func testHeterogeneousKeyPathTypesDoNotCrash() {
    // Different value types, different keyPaths — comparator must safely
    // return false instead of crashing on type-erased cast.
    let textAction = BindingAction.set(\BindableTestReactor.State.text, "hi")
    let intAction = BindingAction.set(\BindableTestReactor.State.count, 5)
    XCTAssertNotEqual(textAction, intAction)
    XCTAssertNotEqual(intAction, textAction)
  }
}

// MARK: - @Bindable subscript integration tests

@MainActor
final class ObservedReactorBindableTests: XCTestCase {

  /// Test #1: read-after-write same tick — the entire point of the design.
  func testOptimisticWriteIsImmediatelyVisible() {
    let testReactor = BindableTestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    reactor[dynamicMember: \BindableTestReactor.State.text] = "abc"
    XCTAssertEqual(reactor[dynamicMember: \BindableTestReactor.State.text], "abc")
  }

  /// The optimistic setter must dispatch a binding action so reduce/epics see it.
  func testOptimisticWriteAlsoDispatchesBindingAction() {
    let testReactor = BindableTestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let echoExpect = expectation(description: "binding action observed in mutate")

    reactor[dynamicMember: \BindableTestReactor.State.text] = "hello"

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      MainActor.assumeIsolated {
        XCTAssertEqual(testReactor.observedActions.count, 1)
        if case .binding(let a) = testReactor.observedActions[0] {
          XCTAssertTrue(\BindableTestReactor.State.text ~= a)
        } else {
          XCTFail("expected .binding action")
        }
        echoExpect.fulfill()
      }
    }
    wait(for: [echoExpect], timeout: 3.0)
  }

  /// Test #3: transform — reducer rewrites the value. For ReactorKit's
  /// synchronous Rx pipeline (`.just(.binding(a))` runs on the same thread),
  /// the entire mutate→reduce→state-emit chain completes inside the
  /// dynamic-member setter. The optimistic value is overwritten by the
  /// reduced value before control returns. Net effect: the user sees the
  /// reducer's transformed value with no flicker.
  func testReducerTransformIsAppliedSynchronously() {
    let testReactor = UppercasingReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    reactor[dynamicMember: \UppercasingReactor.State.text] = "abc"
    XCTAssertEqual(
      reactor[dynamicMember: \UppercasingReactor.State.text],
      "ABC",
      "Synchronous Rx reducer should run before the setter returns"
    )
  }

  /// Native Observation per-property scoping (iOS 17+/macOS 14+). This is
  /// the test that matches what SwiftUI actually does in view bodies.
  @available(macOS 14.0, *)
  func testNativePerPropertyScopingReaderNotInvalidatedByOtherProperty() {
    let testReactor = BindableTestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    final class Flag: @unchecked Sendable { var value = false }
    let textInvalidated = Flag()

    withObservationTracking {
      _ = reactor.text
    } onChange: {
      textInvalidated.value = true
    }

    reactor[dynamicMember: \BindableTestReactor.State.count] = 42

    let spun = expectation(description: "runloop spun")
    DispatchQueue.main.async { spun.fulfill() }
    wait(for: [spun], timeout: 1.0)

    XCTAssertFalse(
      textInvalidated.value,
      "native Observation reader of \\.text must not be invalidated when \\.count is written"
    )
  }

  @available(macOS 14.0, *)
  func testNativePerPropertyScopingReaderInvalidatedByMatchingProperty() {
    let testReactor = BindableTestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let textInvalidated = expectation(description: "text reader invalidated")

    withObservationTracking {
      _ = reactor.text
    } onChange: {
      textInvalidated.fulfill()
    }

    reactor[dynamicMember: \BindableTestReactor.State.text] = "hello"

    wait(for: [textInvalidated], timeout: 3.0)
  }

  /// Test that observers tracking the written property DO fire.
  func testWritingPropertyInvalidatesItsObserver() {
    let testReactor = BindableTestReactor()
    let reactor = ObservedReactor(reactor: testReactor)

    let textObserverFired = expectation(description: "text observer fires")
    _withStateTracking {
      _ = reactor[dynamicMember: \BindableTestReactor.State.text]
    } onChange: {
      textObserverFired.fulfill()
    }

    reactor[dynamicMember: \BindableTestReactor.State.text] = "hello"

    wait(for: [textObserverFired], timeout: 3.0)
  }
}
