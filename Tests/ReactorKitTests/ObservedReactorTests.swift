//
//  ObservedReactorTests.swift
//  ReactorKitTests
//
//  Created by Kanghoon Oh on 2025/09/27.
//

#if !os(Linux)
#if canImport(SwiftUI) && canImport(Combine)
import Combine
import SwiftUI
import XCTest

import ReactorKit
import RxSwift

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class ObservedReactorTests: XCTestCase {

  // MARK: - Test Reactor

  final class TestReactor: Reactor {
    enum Action: Equatable {
      case updateValue(Int)
      case updateText(String)
      case asyncAction
    }

    enum Mutation {
      case setValue(Int)
      case setText(String)
      case setLoading(Bool)
    }

    struct State {
      var value = 0
      var text = ""
      var isLoading = false
    }

    let initialState = State()

    func mutate(action: Action) -> Observable<Mutation> {
      switch action {
      case .updateValue(let value):
        .just(.setValue(value))

      case .updateText(let text):
        .just(.setText(text))

      case .asyncAction:
        Observable.concat([
          .just(.setLoading(true)),
          .just(.setValue(999)).delay(.milliseconds(100), scheduler: MainScheduler.instance),
          .just(.setLoading(false)),
        ])
      }
    }

    func reduce(state: State, mutation: Mutation) -> State {
      var newState = state
      switch mutation {
      case .setValue(let value):
        newState.value = value
      case .setText(let text):
        newState.text = text
      case .setLoading(let loading):
        newState.isLoading = loading
      }
      return newState
    }
  }

  // MARK: - Property Wrapper Tests

  func testInitialization() {
    // Given & When
    @ObservedReactor
    var reactor = TestReactor()

    // Then
    XCTAssertEqual(reactor.currentState.value, 0)
    XCTAssertEqual(reactor.currentState.text, "")
    XCTAssertEqual(reactor.currentState.isLoading, false)
  }

  func testStateObservation() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    let expectation = XCTestExpectation(description: "State should update")
    var cancellable: AnyCancellable?

    // When
    cancellable = $reactor.objectWillChange.sink { _ in
      expectation.fulfill()
    }

    reactor.action.onNext(.updateValue(42))

    // Then
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(reactor.currentState.value, 42)

    cancellable?.cancel()
  }

  func testMultipleStateUpdates() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    // When
    reactor.action.onNext(.updateValue(1))
    reactor.action.onNext(.updateValue(2))
    reactor.action.onNext(.updateValue(3))

    // Allow time for updates
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(reactor.currentState.value, 3)
  }

  func testObservedObjectPublishing() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    var updateCount = 0
    let cancellable = $reactor.objectWillChange.sink { _ in
      updateCount += 1
    }

    // When: Multiple state changes
    reactor.action.onNext(.updateValue(1))
    reactor.action.onNext(.updateText("Test"))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then: Should publish updates for each state change
    XCTAssertGreaterThanOrEqual(updateCount, 2, "Should publish for each state change")

    cancellable.cancel()
  }

  func testMemoryManagement() {
    // Given
    weak var weakReactor: TestReactor?

    autoreleasepool {
      @ObservedReactor
      var reactor = TestReactor()

      weakReactor = reactor as? TestReactor

      // Verify it exists and works
      XCTAssertNotNil(weakReactor)
      reactor.action.onNext(.updateValue(42))
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      XCTAssertEqual(reactor.currentState.value, 42)
    }

    // Then: Should be deallocated after leaving scope
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    XCTAssertNil(weakReactor, "Reactor should be deallocated")
  }

  // MARK: - Binding Tests

  func testBindingWithClosures() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    // When
    let binding = $reactor.binding(
      get: { $0.value },
      send: { TestReactor.Action.updateValue($0) },
    )

    // Then
    XCTAssertEqual(binding.wrappedValue, 0)

    // When: Update via binding
    binding.wrappedValue = 100
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(reactor.currentState.value, 100)
  }

  func testBindingWithKeyPath() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    // When
    let binding = $reactor.binding(\.text, send: { TestReactor.Action.updateText($0) })

    // Then
    XCTAssertEqual(binding.wrappedValue, "")

    // When: Update via binding
    binding.wrappedValue = "Hello"
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(reactor.currentState.text, "Hello")
  }

  func testMultipleBindings() {
    // Given
    @ObservedReactor
    var reactor = TestReactor()

    let valueBinding = $reactor.binding(\.value, send: { TestReactor.Action.updateValue($0) })
    let textBinding = $reactor.binding(\.text, send: { TestReactor.Action.updateText($0) })

    // When
    valueBinding.wrappedValue = 99
    textBinding.wrappedValue = "World"
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(reactor.currentState.value, 99)
    XCTAssertEqual(reactor.currentState.text, "World")
  }
}

#endif // canImport(SwiftUI) && canImport(Combine)
#endif // !os(Linux)
