import XCTest
import ReactorKit
import RxExpect
import RxSwift
import RxTest

final class ReactorTests: XCTestCase {
  func testEachMethodsAreInvoked() {
    RxExpect { test in
      let reactor = TestReactor()
      test.input(reactor.action, [
        next(100, ["action"]),
      ])
      test.assert(reactor.state)
        .filterNext()
        .equal([
          ["transformedState"], // initial state
          ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"],
        ])
    }
  }

  func testStateReplayCurrentState() {
    RxExpect { test in
      let reactor = CounterReactor()
      let disposable = reactor.state.subscribe() // state: 0
      reactor.action.onNext() // state: 1
      reactor.action.onNext() // state: 2
      disposable.dispose()
      test.assert(reactor.state) // last element should be '2'
        .filterNext()
        .equal([2])
    }
  }

  func testCurrentState() {
    let reactor = TestReactor()
    _ = reactor.state
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"])
  }

  func testCurrentState_noState() {
    let reactor = TestReactor()
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, [])
  }

  func testStreamNotContainsError() {
    RxExpect { test in
      let reactor = TestReactor()
      reactor.shouldEmitErrorOnMutate = true
      test.input(reactor.action, [
        next(100, ["action"]),
      ])
      test.assert(reactor.state)
        .not()
        .since(100)
        .contains { event in
          if case .error = event.value {
            return true
          } else {
            return false
          }
        }
    }
  }

  func testStreamNotContainsCompleted() {
    RxExpect { test in
      let reactor = TestReactor()
      reactor.shouldCompleteOnMutate = true
      test.input(reactor.action, [
        next(100, ["action"]),
      ])
      test.assert(reactor.state)
        .not()
        .contains { event in
          if case .completed = event.value {
            return true
          } else {
            return false
          }
        }
    }
  }

  func testCancel() {
    RxExpect { test in
      let reactor = StopwatchReactor(scheduler: test.scheduler)
      test.input(reactor.action, [
        next(1, .start),
        next(5, .stop),
        next(6, .start),
        next(9, .stop),
      ])
      test.assert(reactor.state)
        .filterNext()
        .equal([
          0, // 0
             // 1 (start)
          1, // 2
          2, // 3
          3, // 4
             // 5 (stop)
             // 6 (start)
          4, // 7
          5, // 8
             // 9 (stop)
        ])
    }
  }
}

struct TestError: Error {
}

private final class TestReactor: Reactor {
  typealias Action = [String]
  typealias Mutation = [String]
  typealias State = [String]

  let initialState = State()
  var shouldEmitErrorOnMutate = false
  var shouldCompleteOnMutate = false

  // 1. ["action"] + ["transformedAction"]
  func transform(action: Observable<Action>) -> Observable<Action> {
    return action.map { action in action + ["transformedAction"] }
  }

  // 2. ["action", "transformedAction"] + ["mutation"]
  func mutate(action: Action) -> Observable<Mutation> {
    if self.shouldEmitErrorOnMutate {
      return .error(TestError())
    } else if self.shouldCompleteOnMutate {
      return .empty()
    } else {
      return .just(action + ["mutation"])
    }
  }

  // 3. ["action", "transformedAction", "mutation"] + ["transformedMutation"]
  func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
    return mutation.map { $0 + ["transformedMutation"] }
  }

  // 4. [] + ["action", "transformedAction", "mutation", "transformedMutation"]
  func reduce(state: State, mutation: Mutation) -> State {
    return state + mutation
  }

  // 5. ["action", "transformedAction", "mutation", "transformedMutation"] + ["transformedState"]
  func transform(state: Observable<State>) -> Observable<State> {
    return state.map { $0 + ["transformedState"] }
  }
}


private final class StopwatchReactor: Reactor {
  enum Action {
    case start
    case stop
  }
  typealias Mutation = Int
  typealias State = Int

  private let scheduler: SchedulerType
  let initialState = 0

  init(scheduler: SchedulerType) {
    self.scheduler = scheduler
  }

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .start:
      let stopAction = self.action.filter { $0 == .stop }
      return Observable<Int>.interval(1, scheduler: self.scheduler)
        .map { _ in 1 }
        .takeUntil(stopAction)

    case .stop:
      return .empty()
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    return state + mutation
  }
}

private final class CounterReactor: Reactor {
  typealias Action = Void
  typealias Mutation = Void
  typealias State = Int
  let initialState = 0

  func reduce(state: State, mutation: Mutation) -> State {
    return state + 1
  }
}
