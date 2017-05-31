import XCTest
import ReactorKit
import RxExpect
import RxSwift
import RxTest

final class ReactorTests: XCTestCase {
  func testEachMethodsAreInvoked() {
    RxExpect { test in
      let reactor = test.retain(TestReactor())
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
      let reactor = test.retain(CounterReactor())
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

  func testStreamIgnoresErrorFromAction() {
    RxExpect { test in
      let reactor = test.retain(CounterReactor())
      let action1 = test.scheduler.createHotObservable([
        next(100),
        next(200),
        error(300, TestError()),
        next(400),
      ])
      let action2 = test.scheduler.createHotObservable([
        error(300, TestError()),
        next(500),
        next(600),
      ])
      action1.subscribe(reactor.action).disposed(by: test.disposeBag)
      action2.subscribe(reactor.action).disposed(by: test.disposeBag)
      test.assert(reactor.state)
        .equal([
          next(0, 0),
          next(100, 1),
          next(200, 2),
          next(400, 3),
          next(500, 4),
          next(600, 5),
        ])
    }
  }

  func testStreamIgnoresErrorFromMutate() {
    RxExpect { test in
      let reactor = test.retain(CounterReactor())
      reactor.stateForTriggerError = 2
      test.input(reactor.action, [
        next(100),
        next(200),
        next(300), // error will be emit on this mutate
        next(400),
        next(500),
      ])
      test.assert(reactor.state)
        .equal([0, 1, 2, 3, 4, 5])
    }
  }

  func testStreamIgnoresCompletedFromAction() {
    RxExpect { test in
      let reactor = test.retain(CounterReactor())
      let action1 = test.scheduler.createHotObservable([
        next(100),
        next(200),
        completed(300),
        next(400),
      ])
      let action2 = test.scheduler.createHotObservable([
        completed(300),
        next(500),
        next(600),
      ])
      action1.subscribe(reactor.action).disposed(by: test.disposeBag)
      action2.subscribe(reactor.action).disposed(by: test.disposeBag)
      test.assert(reactor.state)
        .equal([
          next(0, 0),
          next(100, 1),
          next(200, 2),
          next(400, 3),
          next(500, 4),
          next(600, 5),
        ])
    }
  }

  func testStreamIgnoresCompletedFromMutate() {
    RxExpect { test in
      let reactor = test.retain(CounterReactor())
      reactor.stateForTriggerCompleted = 2
      test.input(reactor.action, [
        next(100),
        next(200),
        next(300), // completed will be emit on this mutate
        next(400),
        next(500),
      ])
      test.assert(reactor.state)
        .equal([0, 1, 2, 3, 4, 5])
    }
  }

  func testCancel() {
    RxExpect { test in
      let reactor = test.retain(StopwatchReactor(scheduler: test.scheduler))
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

  // 1. ["action"] + ["transformedAction"]
  func transform(action: Observable<Action>) -> Observable<Action> {
    return action.map { action in action + ["transformedAction"] }
  }

  // 2. ["action", "transformedAction"] + ["mutation"]
  func mutate(action: Action) -> Observable<Mutation> {
    return .just(action + ["mutation"])
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

  var stateForTriggerError: State?
  var stateForTriggerCompleted: State?

  func mutate(action: Void) -> Observable<Void> {
    if self.currentState == self.stateForTriggerError {
      return Observable.concat(.just(action), .error(TestError()))
    } else if self.currentState == self.stateForTriggerCompleted {
      return Observable.concat(.just(action), .empty())
    } else {
      return .just(action)
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    return state + 1
  }
}
