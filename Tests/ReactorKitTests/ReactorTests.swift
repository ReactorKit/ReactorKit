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
      test
        .assert(reactor.state)
        .filterNext()
        .equal([
          ["transformedState"], // initial state
          ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"],
        ])
    }
  }
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
