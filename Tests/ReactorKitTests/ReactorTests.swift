import XCTest
import ReactorKit
import RxSwift
import RxTest

final class ReactorTests: XCTestCase {
  func testEachMethodsAreInvoked() {
    // given
    let reactor = TestReactor()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    scheduler
      .createHotObservable([
        .next(100, ["action"]),
      ])
      .subscribe(reactor.action)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events.count, 2)
    XCTAssertEqual(response.events[0].value.element, ["transformedState"]) // initial state
    XCTAssertEqual(response.events[1].value.element, [
      "action",
      "transformedAction",
      "mutation",
      "transformedMutation",
      "reduce",
      "transformedState"
    ])
  }

  func testReduceIsExecutedRightAfterMutation() {
    final class MyReactor: Reactor {
      enum Action {
        case append([String])
      }

      enum Mutation {
        case setCharacters([String])
      }

      struct State {
        var characters: [String] = []
      }

      let initialState = State()

      func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case let .append(characters):
          let sources: [Observable<Mutation>] = characters.map { character in
            Observable<Mutation>.create { [weak self] observer in
              if let self = self {
                let newCharacters = self.currentState.characters + [character]
                observer.onNext(Mutation.setCharacters(newCharacters))
              }
              observer.onCompleted()
              return Disposables.create()
            }
          }
          return Observable.concat(sources)
        }
      }

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case let .setCharacters(newCharacters):
          newState.characters = newCharacters
        }
        return newState
      }
    }

    let reactor = MyReactor()
    reactor.action.onNext(.append(["a", "b"]))
    reactor.action.onNext(.append(["c"]))
    reactor.action.onNext(.append(["d", "e", "f"]))
    XCTAssertEqual(reactor.currentState.characters, ["a", "b", "c", "d", "e", "f"])
  }

  func testStateReplayCurrentState() {
    // given
    let reactor = CounterReactor()
    let scheduler = TestScheduler(initialClock: 0)

    // when
    let disposable = reactor.state.subscribe() // state: 0
    reactor.action.onNext(Void()) // state: 1
    reactor.action.onNext(Void()) // state: 2
    disposable.dispose()

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events.map(\.value.element), [2])
  }

  func testCurrentState() {
    let reactor = TestReactor()
    _ = reactor.state
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "reduce", "transformedState"])
  }

  func testCurrentState_stateIsCreatedWhenAccessAction() {
    let reactor = TestReactor()
    reactor.action.onNext(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "reduce", "transformedState"])
  }

  func testStreamIgnoresErrorFromAction() {
    // given
    let reactor = CounterReactor()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    let action1 = scheduler.createHotObservable([
      .next(100, Void()),
      .next(200, Void()),
      .error(300, TestError()),
      .next(400, Void()),
    ])
    let action2 = scheduler.createHotObservable([
      .error(300, TestError()),
      .next(500, Void()),
      .next(600, Void()),
    ])
    action1.subscribe(reactor.action).disposed(by: disposeBag)
    action2.subscribe(reactor.action).disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events, [
      .next(0, 0),
      .next(100, 1),
      .next(200, 2),
      .next(400, 3),
      .next(500, 4),
      .next(600, 5),
    ])
  }

  func testStreamIgnoresErrorFromMutate() {
    // given
    let reactor = CounterReactor()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    reactor.stateForTriggerError = 2

    // when
    scheduler
      .createHotObservable([
        .next(100, Void()),
        .next(200, Void()),
        .next(300, Void()), // error will be emit on this mutate
        .next(400, Void()),
        .next(500, Void()),
      ])
      .subscribe(reactor.action)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events.map(\.value.element), [0, 1, 2, 3, 4, 5])
  }

  func testStreamIgnoresCompletedFromAction() {
    // given
    let reactor = CounterReactor()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    let action1 = scheduler.createHotObservable([
      .next(100, Void()),
      .next(200, Void()),
      .completed(300),
      .next(400, Void()),
    ])
    let action2 = scheduler.createHotObservable([
      .completed(300),
      .next(500, Void()),
      .next(600, Void()),
    ])
    action1.subscribe(reactor.action).disposed(by: disposeBag)
    action2.subscribe(reactor.action).disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events, [
      .next(0, 0),
      .next(100, 1),
      .next(200, 2),
      .next(400, 3),
      .next(500, 4),
      .next(600, 5),
    ])
  }

  func testStreamIgnoresCompletedFromMutate() {
    // given
    let reactor = CounterReactor()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    reactor.stateForTriggerCompleted = 2

    // when
    scheduler
      .createHotObservable([
        .next(100, Void()),
        .next(200, Void()),
        .next(300, Void()), // completed will be emit on this mutate
        .next(400, Void()),
        .next(500, Void()),
      ])
      .subscribe(reactor.action)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events.map(\.value.element), [0, 1, 2, 3, 4, 5])
  }

  func testCancel() {
    // given
    let scheduler = TestScheduler(initialClock: 0)
    let reactor = StopwatchReactor(scheduler: scheduler)
    let disposeBag = DisposeBag()

    // when
    scheduler
      .createHotObservable([
        .next(1, .start),
        .next(5, .stop),
        .next(6, .start),
        .next(9, .stop),
      ])
      .subscribe(reactor.action)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { reactor.state }
    XCTAssertEqual(response.events.map(\.value.element), [
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

  func testStub_actionAndStateMemoryAddress() {
    let reactor = TestReactor()
    reactor.isStubEnabled = true
    XCTAssertTrue(reactor.action === reactor.stub.action)
    XCTAssertTrue(reactor.state === reactor.stub.state.asObservable())
  }

  func testStub_actions() {
    let reactor = StopwatchReactor(scheduler: MainScheduler.instance)
    reactor.isStubEnabled = true
    reactor.action.onNext(.start)
    reactor.action.onNext(.start)
    reactor.action.onNext(.stop)
    XCTAssertEqual(reactor.stub.actions, [.start, .start, .stop])
  }

  func testStub_state() {
    let reactor = StopwatchReactor(scheduler: MainScheduler.instance)
    reactor.isStubEnabled = true
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
    reactor.isStubEnabled = true
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

  func testDispose() {
    weak var weakReactor: TestReactor?
    weak var weakAction: ActionSubject<TestReactor.Action>?
    weak var weakState: Observable<TestReactor.State>?

    _ = {
      let reactor = TestReactor()
      weakReactor = reactor
      weakAction = reactor.action
      weakState = reactor.state
    }()

    XCTAssertNil(weakReactor)
    XCTAssertNil(weakAction)
    XCTAssertNil(weakState)
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

  // 4. [] + ["action", "transformedAction", "mutation", "transformedMutation"] + ["reduce"]
  func reduce(state: State, mutation: Mutation) -> State {
    return state + mutation + ["reduce"]
  }

  // 5. ["action", "transformedAction", "mutation", "transformedMutation", "reduce"] + ["transformedState"]
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
      return Observable<Int>.interval(.seconds(1), scheduler: self.scheduler)
        .map { _ in 1 }
        .take(until: stopAction)

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
