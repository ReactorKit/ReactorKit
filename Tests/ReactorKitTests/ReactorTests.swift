import XCTest
import ReactorKit
import RxExpect
import RxSwift
import RxTest

final class ReactorTests: XCTestCase {
  func testEachMethodsAreInvoked() {
    let test = RxExpect()
    let reactor = test.retain(TestReactor())
    test.input(reactor.action, [
      next(100, ["action"]),
    ])
    test.assert(reactor.state) { events in
      XCTAssertEqual(events.elements.count, 2)
      XCTAssertEqual(events.elements[0], ["transformedState"]) // initial state
      XCTAssertEqual(events.elements[1], ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"])
    }
  }

  func testStateReplayCurrentState() {
    let test = RxExpect()
    let reactor = test.retain(CounterReactor())
    let disposable = reactor.state.subscribe() // state: 0
    reactor.action.onNext(Void()) // state: 1
    reactor.action.onNext(Void()) // state: 2
    disposable.dispose()
    test.assert(reactor.state) { events in
      XCTAssertEqual(events.elements, [2])
    }
  }

  func testCurrentState() {
    let reactor = TestReactor()
    _ = reactor.state
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"])
  }

  func testCurrentState_stateIsCreatedWhenAccessAction() {
    let reactor = TestReactor()
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "transformedState"])
  }

  func testStreamIgnoresErrorFromAction() {
    let test = RxExpect()
    let reactor = test.retain(CounterReactor())
    let action1 = test.scheduler.createHotObservable([
      next(100, Void()),
      next(200, Void()),
      error(300, TestError()),
      next(400, Void()),
    ])
    let action2 = test.scheduler.createHotObservable([
      error(300, TestError()),
      next(500, Void()),
      next(600, Void()),
    ])
    action1.subscribe(reactor.action).disposed(by: test.disposeBag)
    action2.subscribe(reactor.action).disposed(by: test.disposeBag)
    test.assert(reactor.state) { events in
      XCTAssertEqual(events, [
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
    let test = RxExpect()
    let reactor = test.retain(CounterReactor())
    reactor.stateForTriggerError = 2
    test.input(reactor.action, [
      next(100, Void()),
      next(200, Void()),
      next(300, Void()), // error will be emit on this mutate
      next(400, Void()),
      next(500, Void()),
    ])
    test.assert(reactor.state) { events in
      XCTAssertEqual(events.elements, [0, 1, 2, 3, 4, 5])
    }
  }

  func testStreamIgnoresCompletedFromAction() {
    let test = RxExpect()
    let reactor = test.retain(CounterReactor())
    let action1 = test.scheduler.createHotObservable([
      next(100, Void()),
      next(200, Void()),
      completed(300),
      next(400, Void()),
    ])
    let action2 = test.scheduler.createHotObservable([
      completed(300),
      next(500, Void()),
      next(600, Void()),
    ])
    action1.subscribe(reactor.action).disposed(by: test.disposeBag)
    action2.subscribe(reactor.action).disposed(by: test.disposeBag)
    test.assert(reactor.state) { events in
      XCTAssertEqual(events, [
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
    let test = RxExpect()
    let reactor = test.retain(CounterReactor())
    reactor.stateForTriggerCompleted = 2
    test.input(reactor.action, [
      next(100, Void()),
      next(200, Void()),
      next(300, Void()), // completed will be emit on this mutate
      next(400, Void()),
      next(500, Void()),
    ])
    test.assert(reactor.state) { events in
      XCTAssertEqual(events.elements, [0, 1, 2, 3, 4, 5])
    }
  }

  func testCancel() {
    let test = RxExpect()
    let reactor = test.retain(StopwatchReactor(scheduler: test.scheduler))
    test.input(reactor.action, [
      next(1, .start),
      next(5, .stop),
      next(6, .start),
      next(9, .stop),
    ])
    test.assert(reactor.state) { events in
      XCTAssertEqual(events.elements, [
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

  func testStub_actionAndStateMemoryAddress() {
    let reactor = TestReactor()
    reactor.stub.isEnabled = true
    XCTAssertTrue(reactor.action === reactor.stub.action)
    XCTAssertTrue(reactor.state === reactor.stub.state.asObservable())
  }

  func testStub_actions() {
    let reactor = StopwatchReactor(scheduler: MainScheduler.instance)
    reactor.stub.isEnabled = true
    reactor.action.onNext(.start)
    reactor.action.onNext(.start)
    reactor.action.onNext(.stop)
    XCTAssertEqual(reactor.stub.actions, [.start, .start, .stop])
  }

  func testStub_state() {
    let reactor = StopwatchReactor(scheduler: MainScheduler.instance)
    reactor.stub.isEnabled = true
    reactor.stub.state.value = 0
    XCTAssertEqual(reactor.currentState, 0)
    reactor.stub.state.value = 1
    XCTAssertEqual(reactor.currentState, 1)
    reactor.stub.state.value = -10
    XCTAssertEqual(reactor.currentState, -10)
    reactor.stub.state.value = 30
    XCTAssertEqual(reactor.currentState, 30)
  }

  func testStub_ignoreAction() {
    let reactor = TestReactor()
    reactor.stub.isEnabled = true
    reactor.action.onNext(["A"])
    XCTAssertEqual(reactor.currentState, [])
  }

  /// A test for #30
  func testGenericSubclassing() {
    class ParentReactor<T>: Reactor {
      enum Action {}
      typealias Mutation = Void
      typealias State = Void
      let initialState: State = State()
    }

    class ChildReactor: ParentReactor<String> {
    }

    let reactor = ChildReactor()
    let address1 = ObjectIdentifier(reactor.action).hashValue
    _ = reactor.state
    let address2 = ObjectIdentifier(reactor.action).hashValue
    XCTAssertEqual(address1, address2)
  }

  func testGenericSubclassing_stateIsCreatedWhenAccessAction() {
    class ParentReactor<T>: Reactor {
      enum Action {
        case foo
      }
      typealias Mutation = Void
      typealias State = Int
      let initialState: State = 0

      func mutate(action: Action) -> Observable<Mutation> {
        return .just(Void())
      }

      func reduce(state: State, mutation: Mutation) -> State {
        return state + 1
      }
    }

    class ChildReactor: ParentReactor<String> {
    }

    let reactor = ChildReactor()
    XCTAssertEqual(reactor.currentState, 0)
    reactor.action.onNext(.foo)
    XCTAssertEqual(reactor.currentState, 1)
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
