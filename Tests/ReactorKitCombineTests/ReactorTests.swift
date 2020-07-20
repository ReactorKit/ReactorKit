//
//  ReactorTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/06/30.
//

import XCTest

import Combine
@testable import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ReactorTests: XCTestCase {
  func testEachMethodsAreInvoked() {
    // given
    let reactor = TestReactor()
    var cancellables: Set<AnyCancellable> = []
    var receivedStates: [TestReactor.State] = []
    reactor.state.sink(receiveValue: { receivedStates.append($0) }).store(in: &cancellables)

    // when
    reactor.action.send(["action"])

    // then
    XCTAssertEqual(receivedStates.count, 2)
    XCTAssertEqual(receivedStates[0], ["transformedState"]) // initial state
    XCTAssertEqual(receivedStates[1], ["action", "transformedAction", "mutation", "transformedMutation", "reduce", "transformedState"])
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

      func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        switch action {
        case let .append(characters):
          let sources: [AnyPublisher<Mutation, Never>] = characters.map { character in
            AnyPublisher<Mutation, Never>.create { [weak self] subscriber -> Cancellable in
              if let self = self {
                let newCharacters = self.currentState.characters + [character]
                subscriber.send(Mutation.setCharacters(newCharacters))
              }
              subscriber.send(completion: .finished)
              return AnyCancellable { }
            }
          }
          return sources.publisher.flatMap { $0 }.eraseToAnyPublisher()
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
    reactor.action.send(.append(["a", "b"]))
    reactor.action.send(.append(["c"]))
    reactor.action.send(.append(["d", "e", "f"]))
    XCTAssertEqual(reactor.currentState.characters, ["a", "b", "c", "d", "e", "f"])
  }

  func testStateReplayCurrentState() {
    // given
    let reactor = CounterReactor()

    // when
    let cancellable = reactor.state.sink(receiveValue: { _ in }) // state: 0
    reactor.action.send(()) // state: 1
    reactor.action.send(()) // state: 2
    cancellable.cancel()

    // then
    var latestState: CounterReactor.State?
    _ = reactor.state.sink(receiveValue: { latestState = $0 })
    XCTAssertEqual(latestState, 2)
  }

  func testCurrentState() {
    let reactor = TestReactor()
    _ = reactor.state
    reactor.action.send(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "reduce", "transformedState"])
  }

  func testCurrentState_stateIsCreatedWhenAccessAction() {
    let reactor = TestReactor()
    reactor.action.send(["action"])
    XCTAssertEqual(reactor.currentState, ["action", "transformedAction", "mutation", "transformedMutation", "reduce", "transformedState"])
  }

  func testStreamIgnoresCompletedFromAction() {
    // given
    let reactor = CounterReactor()
    let action1 = ActionSubject<CounterReactor.Action>()
    let action2 = ActionSubject<CounterReactor.Action>()
    var receivedStates: [CounterReactor.State] = []
    var cancellables: Set<AnyCancellable> = []
    action1.subscribe(reactor.action).store(in: &cancellables)
    action2.subscribe(reactor.action).store(in: &cancellables)
    reactor.state.sink(receiveValue: { receivedStates.append($0) }).store(in: &cancellables)

    // when
    action1.send(Void())
    action1.send(Void())
    action1.send(completion: .finished)
    action2.send(completion: .finished)
    action1.send(Void())
    action2.send(Void())
    action2.send(Void())

    // then
    XCTAssertEqual(receivedStates, [0, 1, 2, 3, 4, 5])
  }

  func testStreamIgnoresCompletedFromMutate() {
    // given
    let reactor = CounterReactor()
    reactor.stateForTriggerCompleted = 2
    var cancellables: Set<AnyCancellable> = []
    var receivedStates: [CounterReactor.State] = []
    reactor.state.sink(receiveValue: { receivedStates.append($0) }).store(in: &cancellables)

    // when
    reactor.action.send(Void())
    reactor.action.send(Void())
    reactor.action.send(Void()) // completed will be emit on this mutate
    reactor.action.send(Void())
    reactor.action.send(Void())

    // then
    XCTAssertEqual(receivedStates, [0, 1, 2, 3, 4, 5])
  }

  func testCancel() {
    // given
    let timerPublisher = PassthroughSubject<Date, Never>()
    let reactor = StopwatchReactor(timePublisher: timerPublisher.eraseToAnyPublisher())
    var cancellables: Set<AnyCancellable> = []
    var receivedStates: [StopwatchReactor.State] = []
    reactor.state.sink(receiveValue: { receivedStates.append($0) }).store(in: &cancellables)

    // when
    reactor.action.send(.start) // time: 1
    timerPublisher.send(Date()) // time: 2
    timerPublisher.send(Date()) // time: 3
    timerPublisher.send(Date()) // time: 4
    reactor.action.send(.stop)  // time: 5
    reactor.action.send(.start) // time: 6
    timerPublisher.send(Date()) // time: 7
    timerPublisher.send(Date()) // time: 8
    reactor.action.send(.stop)  // time: 9

    // then
    XCTAssertEqual(receivedStates, [
      0, // time: 0
         // time: 1 (start)
      1, // time: 2
      2, // time: 3
      3, // time: 4
         // time: 5 (stop)
         // time: 6 (start)
      4, // time: 7
      5, // time: 8
         // time: 9 (stop)
    ])
  }

  func testStub_actionAndStateMemoryAddress() {
    let reactor = TestReactor()
    reactor.isStubEnabled = true
    XCTAssertTrue(reactor.action === reactor.stub.action)
    let statePublisher: AnyObject? = {
      let stateMirror = Mirror(reflecting: reactor.state)
      guard let box = stateMirror.children.first(where: { $0.label == "box" })?.value else { return nil }
      let boxMirror = Mirror(reflecting: box)
      let base = boxMirror.children.first { $0.label == "base" }?.value
      return base as AnyObject
    }()
    XCTAssertTrue(statePublisher === reactor.stub.state)
  }

  func testStub_actions() {
    let reactor = StopwatchReactor()
    reactor.isStubEnabled = true
    reactor.action.send(.start)
    reactor.action.send(.start)
    reactor.action.send(.stop)
    XCTAssertEqual(reactor.stub.actions, [.start, .start, .stop])
  }

  func testStub_state() {
    let reactor = StopwatchReactor()
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
    reactor.action.send(["A"])
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

      func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
        return Just(Void()).eraseToAnyPublisher()
      }

      func reduce(state: State, mutation: Mutation) -> State {
        return state + 1
      }
    }

    class ChildReactor: ParentReactor<String> {
    }

    let reactor = ChildReactor()
    XCTAssertEqual(reactor.currentState, 0)
    reactor.action.send(.foo)
    XCTAssertEqual(reactor.currentState, 1)
  }

  func testDispose() {
    // given
    weak var weakReactor: TestReactor?
    weak var weakAction: ActionSubject<TestReactor.Action>?
    weak var weakState: AnyObject?// AnyPublisher<TestReactor.State, Never>?

    // when
    _ = {
      let reactor = TestReactor()
      weakReactor = reactor
      weakAction = reactor.action
      weakState = reactor.state as AnyObject
    }()

    // then
    XCTAssertNil(weakReactor)
    XCTAssertNil(weakAction)
    XCTAssertNil(weakState)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class TestReactor: Reactor {
  typealias Action = [String]
  typealias Mutation = [String]
  typealias State = [String]

  let initialState = State()

  // 1. ["action"] + ["transformedAction"]
  func transform(action: AnyPublisher<Action, Never>) -> AnyPublisher<Action, Never> {
    return action.map { action in action + ["transformedAction"] }.eraseToAnyPublisher()
  }

  // 2. ["action", "transformedAction"] + ["mutation"]
  func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
    return Just(action + ["mutation"]).eraseToAnyPublisher()
  }

  // 3. ["action", "transformedAction", "mutation"] + ["transformedMutation"]
  func transform(mutation: AnyPublisher<Mutation, Never>) -> AnyPublisher<Mutation, Never> {
    return mutation.map { $0 + ["transformedMutation"] }.eraseToAnyPublisher()
  }

  // 4. [] + ["action", "transformedAction", "mutation", "transformedMutation"] + ["reduce"]
  func reduce(state: State, mutation: Mutation) -> State {
    return state + mutation + ["reduce"]
  }

  // 5. ["action", "transformedAction", "mutation", "transformedMutation", "reduce"] + ["transformedState"]
  func transform(state: AnyPublisher<State, Never>) -> AnyPublisher<State, Never> {
    return state.map { $0 + ["transformedState"] }.eraseToAnyPublisher()
  }
}


@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class StopwatchReactor: Reactor {
  enum Action {
    case start
    case stop
  }
  typealias Mutation = Int
  typealias State = Int

  fileprivate let timePublisher: AnyPublisher<Date, Never>
  static let defaultTimePublisher = Timer.publish(every: 1, on: RunLoop.main, in: .default)
    .autoconnect()
    .eraseToAnyPublisher()
  let initialState = 0

  init(timePublisher: AnyPublisher<Date, Never> = StopwatchReactor.defaultTimePublisher) {
    self.timePublisher = timePublisher
  }

  func mutate(action: Action) -> AnyPublisher<Mutation, Never> {
    switch action {
    case .start:
      let stopAction = self.action.filter { $0 == .stop }
      return self.timePublisher
        .map { _ in 1 }
        .prefix(untilOutputFrom: stopAction)
        .eraseToAnyPublisher()

    case .stop:
      return Empty().eraseToAnyPublisher()
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    return state + mutation
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class CounterReactor: Reactor {

  typealias Action = Void
  typealias Mutation = Void
  typealias State = Int
  let initialState = 0

  var stateForTriggerCompleted: State?

  func mutate(action: Void) -> AnyPublisher<Mutation, Never> {
    if self.currentState == self.stateForTriggerCompleted {
      let sources: [AnyPublisher<Mutation, Never>] = [
        Just(action).eraseToAnyPublisher(),
        Empty<Mutation, Never>().eraseToAnyPublisher(),
      ]
      return sources.publisher.flatMap { $0 }.eraseToAnyPublisher()
    } else {
      return Just(action).eraseToAnyPublisher()
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    return state + 1
  }
}
