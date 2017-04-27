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

  func testCurrentState() {
    let disposeBag = DisposeBag()
    let reactor = TestReactor()
    XCTAssertEqual(reactor.currentState, [])
    reactor.state.subscribe().disposed(by: disposeBag)
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"])
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
