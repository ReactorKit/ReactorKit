//
//  BindableViewRenderingTests.swift
//  ReactorKitSwiftUITests
//
//  Created by Kanghoon Oh on 4/12/26.
//
//  Regression sentinel for the `ReactorBindable` Binding-identity bug.
//
//  The bug isn't observable via `withObservationTracking` — it shows up
//  only when SwiftUI runs its view-diff pass. If `ReactorBindable`'s
//  dynamic-member subscript is ever "simplified" from the
//  `ObservedObject` trampoline (`$observer.object[dynamicMember:]`) to a
//  closure-based `Binding(get:set:)`, the returned binding no longer
//  compares equal to its predecessor across parent body re-renders, and
//  SwiftUI re-evaluates every child view that took the binding as an
//  input — even when the underlying property didn't change.
//
//  This test hosts a parent view that reads `reactor.count` (so any
//  `\.count` mutation invalidates the parent body) and passes
//  `$reactor.text` to a child whose body increments a counter. After a
//  `\.count` mutation the child body must NOT have been re-evaluated.
//
//  ## Why this file is iOS-only and manual-run
//
//  - iOS is the platform where the Binding-identity optimization
//    actually engages. A macOS variant using `NSHostingView` produces
//    false positives: macOS SwiftUI re-evaluates child view bodies on
//    parent re-renders even when the Binding identity is stable, so
//    the test cannot distinguish the correct trampoline implementation
//    from a buggy closure-based one.
//
//  - Running this file automatically via
//    `xcodebuild test -scheme ReactorKit-Package -destination 'platform=iOS
//    Simulator,…'` is blocked by a known limitation of Xcode's SPM
//    integration: the `test` action tries to compile the `.macro`
//    target's own Swift sources for the iOS simulator destination,
//    which fails because SwiftSyntax is host-only. `xcodebuild build
//    -destination iOS` works — only the `test` action hits the issue.
//
//  ## How to run
//
//  Open the package in Xcode, change the build destination to an iOS
//  Simulator, and run `BindableViewRenderingTests` from the test
//  navigator. On macOS `swift test` the `#if os(iOS)` guard skips the
//  file entirely, so CI (`swift test`) stays green without executing
//  this sentinel.
//

#if os(iOS)
import SwiftUI
import UIKit
import XCTest

import ReactorKit
import ReactorKitObservation
import ReactorKitSwiftUI
@preconcurrency import RxSwift

// MARK: - Test reactor

@ObservableState
private struct BindingIdentityProbeState {
  var count = 0
  var text = ""
}

private final class BindingIdentityProbeReactor: Reactor {
  enum Action: BindableAction {
    case binding(BindingAction<BindingIdentityProbeState>)
    case incrementCount
  }

  enum Mutation {
    case binding(BindingAction<BindingIdentityProbeState>)
    case incrementCount
  }

  let initialState = BindingIdentityProbeState()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .binding(let a): .just(.binding(a))
    case .incrementCount: .just(.incrementCount)
    }
  }

  func reduce(
    state: BindingIdentityProbeState, mutation: Mutation
  ) -> BindingIdentityProbeState {
    var state = state
    switch mutation {
    case .binding(let a): a.apply(to: &state)
    case .incrementCount: state.count += 1
    }
    return state
  }
}

// MARK: - Body-call counter

@MainActor
private final class BodyCallCounter {
  var value = 0
  func increment() { value += 1 }
}

// MARK: - Probe views

@MainActor
private struct ProbeParentView: View {
  @ReactorBindable var reactor: ObservedReactor<BindingIdentityProbeReactor>
  let childCounter: BodyCallCounter

  var body: some View {
    VStack {
      Text("count: \(reactor.count)")
      ProbeChildView(text: $reactor.text, counter: childCounter)
    }
  }
}

@MainActor
private struct ProbeChildView: View {
  @Binding var text: String
  let counter: BodyCallCounter

  var body: some View {
    let _ = counter.increment()
    return TextField("", text: $text)
  }
}

// MARK: - Test case

@MainActor
final class BindableViewRenderingTests: XCTestCase {

  func testReactorBindableBindingIsDiffedAsEqualAcrossParentRerenders() {
    let reactor = ObservedReactor(reactor: BindingIdentityProbeReactor())
    let childCounter = BodyCallCounter()

    let host = UIHostingController(
      rootView: ProbeParentView(reactor: reactor, childCounter: childCounter)
    )
    host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let baseline = childCounter.value
    XCTAssertGreaterThanOrEqual(
      baseline, 1,
      "initial render should have evaluated ProbeChildView.body at least once"
    )

    reactor.send(.incrementCount)

    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    host.view.layoutIfNeeded()

    XCTAssertEqual(
      childCounter.value, baseline,
      """
      ProbeChildView.body was re-evaluated after a \\.count mutation \
      even though the child only receives $reactor.text. This means \
      the Binding produced by ReactorBindable is NOT being diffed as \
      equal across parent body re-renders — most likely because \
      someone replaced `$observer.object[dynamicMember:]` with a \
      closure-based `Binding(get:set:)`. Restore the ObservedObject \
      trampoline in ReactorBindable.swift.
      """
    )
  }
}

#endif
