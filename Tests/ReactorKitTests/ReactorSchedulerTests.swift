//
//  ReactorSchedulerTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest

import ReactorKit
@preconcurrency import RxSwift

@preconcurrency
final class ReactorSchedulerTests: XCTestCase {

  func testStateStreamIsCreatedOnce() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Never
      typealias Mutation = Never
      typealias State = Int

      let initialState: State = 0

      func transform(action: Observable<Action>) -> Observable<Action> {
        return action
      }
    }

    final class StateBox: @unchecked Sendable {
      var value: [Observable<SimpleReactor.State>] = []
    }

    let reactor = SimpleReactor()
    let states = StateBox()
    let lock = NSLock()
    let expectation = XCTestExpectation()

    for _ in 0..<100 {
      DispatchQueue.global().async {
        let state = reactor.state
        lock.lock()
        states.value.append(state)
        let count = states.value.count
        lock.unlock()

        if count == 100 {
          expectation.fulfill()
        }
      }
    }

    XCTWaiter().wait(for: [expectation], timeout: 10)

    XCTAssertGreaterThan(states.value.count, 0)
    for state in states.value {
      XCTAssertTrue(state === states.value.first)
    }
  }

  func testDefaultScheduler() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var reductionThreads: [Thread] = []
      }

      let initialState = State()

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        newState.reductionThreads.append(Thread.current)
        return newState
      }
    }

    final class ThreadBox: @unchecked Sendable {
      var observationThreads: [Thread] = []
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()
    let threads = ThreadBox()
    let expectation = XCTestExpectation()

    DispatchQueue.global().async {
      reactor.state
        .subscribe(onNext: { _ in
          threads.observationThreads.append(Thread.current)
          if threads.observationThreads.count == 101 { // +1 for initial state
            expectation.fulfill()
          }
        })
        .disposed(by: disposeBag)

      for _ in 0..<100 {
        reactor.action.onNext(Void())
      }
    }

    XCTWaiter().wait(for: [expectation], timeout: 5)

    let reductionThreads = reactor.currentState.reductionThreads
    XCTAssertEqual(reductionThreads.count, 100)
    // Default scheduler is MainScheduler — reduce runs on main.
    for thread in reductionThreads {
      XCTAssertTrue(thread.isMainThread)
    }
    // Post-initial emissions are rescheduled to main via the upstream observe(on:).
    // The initial-state emission (index 0) is delivered on the subscribe thread.
    XCTAssertEqual(threads.observationThreads.count, 101)
    for thread in threads.observationThreads.dropFirst() {
      XCTAssertTrue(thread.isMainThread)
    }
  }

  func testCustomScheduler() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var reductionThreads: [Thread] = []
      }

      let initialState = State()
      let scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .default)

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        newState.reductionThreads.append(Thread.current)
        return newState
      }
    }

    final class ThreadBox: @unchecked Sendable {
      var observationThreads: [Thread] = []
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()
    let threads = ThreadBox()
    let expectation = XCTestExpectation()

    DispatchQueue.global().async {
      reactor.state
        .subscribe(onNext: { _ in
          threads.observationThreads.append(Thread.current)
          if threads.observationThreads.count == 101 {
            expectation.fulfill()
          }
        })
        .disposed(by: disposeBag)

      for _ in 0..<100 {
        reactor.action.onNext(Void())
      }
    }

    XCTWaiter().wait(for: [expectation], timeout: 5)

    let reductionThreads = reactor.currentState.reductionThreads
    XCTAssertEqual(reductionThreads.count, 100)
    // Custom scheduler is a background serial queue — reduce runs off main.
    for thread in reductionThreads {
      XCTAssertFalse(thread.isMainThread)
    }
    XCTAssertEqual(threads.observationThreads.count, 101)
    for thread in threads.observationThreads.dropFirst() {
      XCTAssertFalse(thread.isMainThread)
    }
  }

  /// Verifies the DEBUG action-dispatch contract check does not block or crash
  /// the pipeline when an action is dispatched from a non-main thread under the
  /// default `MainScheduler`. The `os_log` fault emission itself is observable
  /// in Xcode's console; this test only guarantees the check is non-fatal and
  /// preserves correctness so the warning surfaces a real misuse rather than a
  /// regression.
  func testActionDispatchContractCheckIsNonFatal() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var count = 0
      }

      let initialState = State()

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        newState.count += 1
        return newState
      }
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()
    let expectation = XCTestExpectation()

    reactor.state
      .skip(1) // initial state
      .subscribe(onNext: { state in
        if state.count == 1 {
          expectation.fulfill()
        }
      })
      .disposed(by: disposeBag)

    DispatchQueue.global().async {
      reactor.action.onNext(Void())
    }

    XCTWaiter().wait(for: [expectation], timeout: 5)
    XCTAssertEqual(reactor.currentState.count, 1)
  }

  /// Verifies the DEBUG check does not emit when a custom (non-MainScheduler)
  /// scheduler is in use, even if the action is dispatched from a non-main
  /// thread. There is no negative assertion against `os_log` (capture is
  /// platform-dependent); this test pins behavior by exercising the early
  /// `guard scheduler is MainScheduler` exit and confirming correctness.
  func testActionDispatchContractCheckSkippedForCustomScheduler() {
    final class SimpleReactor: Reactor, @unchecked Sendable {
      typealias Action = Void
      typealias Mutation = Void

      struct State {
        var count = 0
      }

      let initialState = State()
      let scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .default)

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        newState.count += 1
        return newState
      }
    }

    let reactor = SimpleReactor()
    let disposeBag = DisposeBag()
    let expectation = XCTestExpectation()

    reactor.state
      .skip(1)
      .subscribe(onNext: { state in
        if state.count == 1 {
          expectation.fulfill()
        }
      })
      .disposed(by: disposeBag)

    DispatchQueue.global().async {
      reactor.action.onNext(Void())
    }

    XCTWaiter().wait(for: [expectation], timeout: 5)
    XCTAssertEqual(reactor.currentState.count, 1)
  }
}
