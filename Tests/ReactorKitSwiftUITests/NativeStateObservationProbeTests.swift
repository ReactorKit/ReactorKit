//
//  NativeStateObservationProbeTests.swift
//  ReactorKitSwiftUITests
//
//  Created by Kanghoon Oh on 4/12/26.
//
//  Verifies that native `Observation.withObservationTracking` sees
//  per-property access on value-type state mediated by
//  `ObservableStateRegistrar`, and that writes only invalidate
//  observers of the matching property.
//

#if canImport(Observation)
import Observation
#endif
import XCTest

import ReactorKit
import ReactorKitObservation
@preconcurrency import RxSwift
@testable import ReactorKitObservation
@testable import ReactorKitSwiftUI

@ObservableState
private struct ProbeState {
  var count = 0
  var text = ""
}

/// Reactor wrapping ProbeState — used to probe the H1 hypothesis: does
/// ObservedReactor's class-level coarse `\.state` fire invalidate readers
/// that are supposed to be per-property-scoped at the state level?
private final class ProbeReactor: Reactor {
  enum Action {
    case incrementCount
    case setText(String)
  }

  enum Mutation {
    case incrementCount
    case setText(String)
  }

  let initialState = ProbeState()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .incrementCount: .just(.incrementCount)
    case .setText(let s): .just(.setText(s))
    }
  }

  func reduce(state: ProbeState, mutation: Mutation) -> ProbeState {
    var state = state
    switch mutation {
    case .incrementCount: state.count += 1 // _modify accessor path
    case .setText(let s): state.text = s
    }
    return state
  }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
final class NativeStateObservationProbeTests: XCTestCase {

  func testDirectWithObservationTrackingSeesPerPropertyAccess() {
    // The "subject" is a single state value whose shared `_$observationRegistrar`
    // backing box is reference-semantic (ref-counted via `_NativeObservationRegistrarBox`).
    var state = ProbeState()

    let onChangeFired = expectation(description: "onChange fires for \\.count")

    withObservationTracking {
      _ = state.count // routes through macro getter → _$observationRegistrar.access
    } onChange: {
      onChangeFired.fulfill()
    }

    // Mutate `\.count` — if the access above registered with native Observation,
    // this mutation fires a matching willSet and onChange runs.
    state.count = 1

    wait(for: [onChangeFired], timeout: 1.0)
  }

  /// H1 probe: with a real ObservedReactor, read \.text via the
  /// dynamic-member subscript under `withObservationTracking`, then fire
  /// an action that only mutates \.count. If per-property scoping holds
  /// end-to-end, onChange for \.text must NOT fire.
  @MainActor
  func testObservedReactorReadOfTextNotInvalidatedByCountMutation() {
    let reactor = ObservedReactor(reactor: ProbeReactor())

    final class Flag: @unchecked Sendable { var value = false }
    let textInvalidated = Flag()

    withObservationTracking {
      _ = reactor.text
    } onChange: {
      textInvalidated.value = true
    }

    reactor.send(.incrementCount)

    // Spin runloop so the Rx → state setter chain completes synchronously
    // on main (ProbeReactor's mutate is `.just(...)` → synchronous).
    let spun = expectation(description: "runloop spun")
    DispatchQueue.main.async { spun.fulfill() }
    wait(for: [spun], timeout: 1.0)

    XCTAssertFalse(
      textInvalidated.value,
      "H1: coarse \\.state fire in ObservedReactor.state setter should not invalidate per-property reader of \\.text"
    )
  }

  /// Mirror test — the matching reader DOES fire.
  @MainActor
  func testObservedReactorReadOfCountInvalidatedByCountMutation() {
    let reactor = ObservedReactor(reactor: ProbeReactor())

    let countInvalidated = expectation(description: "count reader fires")

    withObservationTracking {
      _ = reactor.count
    } onChange: {
      countInvalidated.fulfill()
    }

    reactor.send(.incrementCount)

    wait(for: [countInvalidated], timeout: 2.0)
  }

  // Variant: read via `reactor.state.count` (public state getter returning
  // a copy, then direct `.count` access on the copy). This path goes
  // through the macro getter on the returned state copy — a different
  // code path from `reactor.count` (which goes through the subscript
  // reading `_state[keyPath: \.count]`).
  @MainActor
  func testObservedReactorReadOfStateCountInvalidatedByCountMutation() {
    let reactor = ObservedReactor(reactor: ProbeReactor())

    let countInvalidated = expectation(description: "state.count reader fires")

    withObservationTracking {
      _ = reactor.state.count
    } onChange: {
      countInvalidated.fulfill()
    }

    reactor.send(.incrementCount)

    wait(for: [countInvalidated], timeout: 2.0)
  }

  /// Does mutation on a struct COPY fire observation registered on the
  /// original? If native `ObservationRegistrar` uses subject-pointer
  /// identity for struct subjects, the answer is NO — and that explains
  /// why reactor.count (which records access from one copy, then mutates
  /// via reduce on a different copy) fails to fire.
  func testMutationOnCopyFiresObservationOnOriginal() {
    let stateA = ProbeState()

    let onChangeFired = expectation(
      description: "onChange fires when a COPY of the observed struct is mutated"
    )

    withObservationTracking {
      _ = stateA.count
    } onChange: {
      onChangeFired.fulfill()
    }

    var stateB = stateA // struct copy — shares registrar ref box
    stateB.count = 99

    wait(for: [onChangeFired], timeout: 1.0)
  }

  func testPerPropertyScopingReaderNotInvalidatedByOtherPropertyWrite() {
    var state = ProbeState()

    final class Flag: @unchecked Sendable { var value = false }
    let textFired = Flag()

    withObservationTracking {
      _ = state.text
    } onChange: {
      textFired.value = true
    }

    state.count = 42 // different property

    // Give the observation callback a chance to fire (it shouldn't).
    let spun = expectation(description: "runloop spun")
    DispatchQueue.main.async { spun.fulfill() }
    wait(for: [spun], timeout: 0.5)

    XCTAssertFalse(
      textFired.value,
      "native Observation reader of \\.text should not fire when \\.count is mutated"
    )
  }
}
