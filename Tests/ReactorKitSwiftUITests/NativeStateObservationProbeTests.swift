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

/// Reactor whose `.increase` mutation hops BG → Main inside `Observable.concat`
/// before emitting the value-changing mutation. Mirrors the user-reported
/// pattern from `Examples/SwiftUICounter`.
@ObservableState
private struct BackgroundHopState {
  var count = 0
  var isLoading = false
}

/// Trampoline that mirrors SwiftUI's `withObservationTracking` lifecycle:
/// each `onChange` fire schedules an async snapshot of the reactor's state,
/// then re-installs tracking. Captures successive snapshots so the test can
/// assert on the post-mutation values that SwiftUI body would read.
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
private final class _BackgroundHopTrampoline {
  let reactor: ObservedReactor<BackgroundHopReactor>
  var snapshots: [(isLoading: Bool, count: Int)] = []
  var bothFires: XCTestExpectation?

  init(reactor: ObservedReactor<BackgroundHopReactor>) {
    self.reactor = reactor
  }

  func trackAndCapture() {
    withObservationTracking {
      _ = reactor.isLoading
      _ = reactor.count
    } onChange: { [weak self] in
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          guard let self else { return }
          self.snapshots.append((self.reactor.isLoading, self.reactor.count))
          self.bothFires?.fulfill()
          if self.snapshots.count < 2 {
            self.trackAndCapture()
          }
        }
      }
    }
  }
}

/// Trampoline that re-tracks until it captures a snapshot whose `count`
/// matches `targetCount` — the value the next `.increaseValue` mutation
/// will produce. Used by the sequential pin test where each `.increase`
/// completes before the next is sent.
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor
private final class _BackgroundHopValueCaptureTrampoline {
  let reactor: ObservedReactor<BackgroundHopReactor>
  var targetCount: Int = 0
  var captured: XCTestExpectation?
  var onCapture: ((Int) -> Void)?

  init(reactor: ObservedReactor<BackgroundHopReactor>) {
    self.reactor = reactor
  }

  func trackAndCapture() {
    withObservationTracking {
      _ = reactor.isLoading
      _ = reactor.count
    } onChange: { [weak self] in
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          guard let self else { return }
          let count = self.reactor.count
          if count == self.targetCount && !self.reactor.isLoading {
            self.onCapture?(count)
            self.captured?.fulfill()
          } else {
            self.trackAndCapture()
          }
        }
      }
    }
  }
}

private final class BackgroundHopReactor: Reactor {
  enum Action { case increase }
  enum Mutation {
    case setLoading(Bool)
    case increaseValue
  }

  let initialState = BackgroundHopState()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .increase:
      return Observable.concat([
        .just(.setLoading(true)),
        Observable.create { observer in
          observer.onNext(())
          observer.onCompleted()
          return Disposables.create()
        }
        .subscribe(on: SerialDispatchQueueScheduler(qos: .userInteractive))
        .observe(on: MainScheduler.instance)
        .flatMap { Observable<Mutation>.empty() },
        Observable.just(.increaseValue),
      ])
    }
  }

  func reduce(state: BackgroundHopState, mutation: Mutation) -> BackgroundHopState {
    var state = state
    switch mutation {
    case .setLoading(let loading):
      state.isLoading = loading
    case .increaseValue:
      state.count += 1
      state.isLoading = false
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

  /// Reproduces the BG-hop + native Observation race that pins SwiftUI's
  /// body to a stale `_state`.
  ///
  /// The user-reported pattern: `mutate(.increase)` returns a `concat` of
  /// `[setLoading(true), Observable.create+subscribe(on:bg)+observe(on:MainScheduler.instance)+flatMap{empty},
  /// just(.increaseValue)]`. The inner `.observe(on: MainScheduler.instance)`
  /// increments `MainScheduler.instance.numberEnqueued`, so when
  /// `ObservedReactor.init`'s nested `.observe(on: MainScheduler.instance)`
  /// is reached for delivering the `.increaseValue` state, it falls through
  /// to `dispatch_async`. Meanwhile the macro's `_$mutate` fires native
  /// Observation `willSet` synchronously inside `reduce`. SwiftUI schedules
  /// body re-eval in response — and that re-eval runs BEFORE the deferred
  /// `_state = newValue` assignment, so body reads the previous state.
  ///
  /// The test mirrors SwiftUI's behavior by capturing state inside an
  /// async block scheduled from `withObservationTracking`'s `onChange`.
  /// With the race present, the second snapshot reads stale state
  /// (`isLoading=true, count=0`) instead of the post-`.increaseValue`
  /// state (`isLoading=false, count=1`).
  @MainActor
  func testBodyReEvaluatesAgainstFreshStateAfterBackgroundHop() {
    let reactor = ObservedReactor(reactor: BackgroundHopReactor())

    let trampoline = _BackgroundHopTrampoline(reactor: reactor)
    trampoline.bothFires = expectation(description: "two body re-eval snapshots captured")
    trampoline.bothFires?.expectedFulfillmentCount = 2

    trampoline.trackAndCapture()

    reactor.send(.increase)

    wait(for: [trampoline.bothFires!], timeout: 3.0)

    XCTAssertEqual(trampoline.snapshots.count, 2, "expected 2 onChange-driven snapshots")

    // Snapshot 0 is from `.setLoading(true)` — sync delivery, fresh state.
    XCTAssertTrue(trampoline.snapshots[0].isLoading, "snapshot 0 (post-setLoading) should see isLoading=true")
    XCTAssertEqual(trampoline.snapshots[0].count, 0, "snapshot 0 (post-setLoading) should see count=0")

    // Snapshot 1 is from `.increaseValue` after the BG hop. With the bug,
    // SwiftUI body re-eval reads stale `_state` because `_state = newValue`
    // is deferred past the body re-eval.
    XCTAssertEqual(
      trampoline.snapshots[1].count, 1,
      "snapshot 1 (post-increaseValue) should see count=1 — body re-eval read stale `_state`"
    )
    XCTAssertFalse(
      trampoline.snapshots[1].isLoading,
      "snapshot 1 (post-increaseValue) should see isLoading=false — body re-eval read stale `_state`"
    )
  }

  /// Pins the BG-hop body-race fix against future regressions.
  ///
  /// Issues 5 sequential `.increase` actions, each completing before the
  /// next is sent. For every `.increase`, the test installs a fresh
  /// `withObservationTracking` scope mirroring SwiftUI's per-render
  /// tracking, then captures the post-mutation `(isLoading, count)`
  /// snapshot through the async block scheduled from `onChange`.
  ///
  /// Asserts that each captured snapshot reflects the post-`.increaseValue`
  /// state — `count` strictly increasing 1, 2, 3, 4, 5 — i.e., body re-eval
  /// always reads fresh `_state` regardless of how many times the
  /// reactor pipeline has bumped any process-wide scheduler counter on
  /// previous mutations.
  ///
  /// If the `_state = newValue` assignment ever regresses to deferred
  /// scheduling (the original race), the captured count would either
  /// stick at the previous value or skip — and this test would catch it.
  @MainActor
  func testRepeatedBackgroundHopMutationsPinFreshStateReads() {
    let reactor = ObservedReactor(reactor: BackgroundHopReactor())

    var capturedCounts: [Int] = []

    for expected in 1...5 {
      let trampoline = _BackgroundHopValueCaptureTrampoline(reactor: reactor)
      trampoline.targetCount = expected
      trampoline.captured = expectation(description: "captured count=\(expected)")
      trampoline.onCapture = { capturedCounts.append($0) }
      trampoline.trackAndCapture()

      reactor.send(.increase)

      wait(for: [trampoline.captured!], timeout: 2.0)
    }

    XCTAssertEqual(
      capturedCounts, [1, 2, 3, 4, 5],
      "each body re-eval should read the post-`.increaseValue` count — got \(capturedCounts)"
    )
    XCTAssertFalse(reactor.isLoading)
    XCTAssertEqual(reactor.count, 5)
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
