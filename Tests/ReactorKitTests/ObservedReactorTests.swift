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
      case triggerAlert(String)
      case asyncAction
    }

    enum Mutation {
      case setValue(Int)
      case setText(String)
      case setAlert(String)
      case setLoading(Bool)
    }

    struct State {
      var value = 0
      var text = ""
      var isLoading = false
      @Pulse var alertMessage: String?
    }

    let initialState = State()

    func mutate(action: Action) -> Observable<Mutation> {
      switch action {
      case .updateValue(let value):
        .just(.setValue(value))

      case .updateText(let text):
        .just(.setText(text))

      case .triggerAlert(let message):
        .just(.setAlert(message))

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
      case .setAlert(let message):
        newState.alertMessage = message
      case .setLoading(let loading):
        newState.isLoading = loading
      }
      return newState
    }
  }

  // MARK: - Tests

  func testInitialization() {
    // When
    let observedReactor = ObservedReactor(wrappedValue: TestReactor())

    // Then
    XCTAssertEqual(observedReactor.wrappedValue.currentState.value, 0)
    XCTAssertEqual(observedReactor.projectedValue.state.value, 0)
  }

  func testStateObservation() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    let expectation = XCTestExpectation(description: "State should update")
    var cancellable: AnyCancellable?

    // When
    cancellable = wrapper.objectWillChange.sink { _ in
      expectation.fulfill()
    }

    wrapper.send(.updateValue(42))

    // Then
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(wrapper.state.value, 42)

    cancellable?.cancel()
  }

  func testMultipleStateUpdates() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    // When
    wrapper.send(.updateValue(1))
    wrapper.send(.updateValue(2))
    wrapper.send(.updateValue(3))

    // Allow time for updates
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(wrapper.state.value, 3)
  }

  func testBindingCreation() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    // When: Create binding with closures
    let binding = wrapper.binding(
      get: { $0.value },
      send: { TestReactor.Action.updateValue($0) },
    )

    // Then
    XCTAssertEqual(binding.wrappedValue, 0)

    // When: Update through binding
    binding.wrappedValue = 100
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(wrapper.state.value, 100)
  }

  func testBindingWithKeyPath() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    // When: Create binding with KeyPath
    let binding = wrapper.binding(
      \.text,
      send: { TestReactor.Action.updateText($0) },
    )

    // Then
    XCTAssertEqual(binding.wrappedValue, "")

    // When: Update through binding
    binding.wrappedValue = "Hello"
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(wrapper.state.text, "Hello")
  }

  func testDynamicMemberLookup() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    // When
    wrapper.send(.updateValue(42))
    wrapper.send(.updateText("Test"))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then: Access state properties directly via dynamic member lookup
    XCTAssertEqual(wrapper[dynamicMember: \.value], 42)
    XCTAssertEqual(wrapper[dynamicMember: \.text], "Test")
    XCTAssertEqual(wrapper[dynamicMember: \.isLoading], false)
  }

  func testFunctionCallSyntax() {
    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    // When: Use send method
    wrapper.send(.updateValue(42))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then
    XCTAssertEqual(wrapper.value, 42)
  }

  func testWrapperDoesNotRetainCycle() {
    // Given
    weak var weakReactor: TestReactor?
    weak var weakWrapper: ObservedReactor<TestReactor>.Wrapper?

    autoreleasepool {
      let reactor = TestReactor()
      let observedReactor = ObservedReactor(wrappedValue: reactor)
      let wrapper = observedReactor.projectedValue

      weakReactor = reactor
      weakWrapper = wrapper

      // Verify they exist
      XCTAssertNotNil(weakReactor)
      XCTAssertNotNil(weakWrapper)

      // Use them
      wrapper.send(.updateValue(42))
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      XCTAssertEqual(wrapper.state.value, 42)
    }

    // Then: Should be deallocated after leaving scope
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    XCTAssertNil(weakReactor, "Reactor should be deallocated")
    XCTAssertNil(weakWrapper, "Wrapper should be deallocated")
  }

  // MARK: - SwiftUI Integration

  func testPropertyWrapperUsageSimulation() {
    // Simulates @ObservedReactor usage in a SwiftUI View.
    // Verifies PropertyWrapper behavior without UI testing tools.

    // Test new syntax: @ObservedReactor var reactor = TestReactor()
    let property1 = ObservedReactor(wrappedValue: TestReactor())
    let wrappedReactor1 = property1.wrappedValue
    XCTAssertNotNil(wrappedReactor1)
    XCTAssertEqual(property1.projectedValue.state.value, 0)

    // Test injection syntax: @ObservedReactor(injected) var reactor
    let injectedReactor = TestReactor()
    let property2 = ObservedReactor(wrappedValue: injectedReactor)
    let wrappedReactor2 = property2.wrappedValue
    XCTAssertTrue(wrappedReactor2 === injectedReactor)

    // Verify state access and action sending
    let wrapper = property2.projectedValue
    wrapper.send(.updateValue(10))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    XCTAssertEqual(wrapper.state.value, 10)
  }

  func testObservedObjectPublishing() {
    // Verifies Wrapper triggers SwiftUI updates via objectWillChange

    // Given
    let reactor = TestReactor()
    let observedReactor = ObservedReactor(wrappedValue: reactor)
    let wrapper = observedReactor.projectedValue

    var updateCount = 0
    let cancellable = wrapper.objectWillChange.sink { _ in
      updateCount += 1
    }

    // When: Multiple state changes
    wrapper.send(.updateValue(1))
    wrapper.send(.updateText("Test"))
    wrapper.send(.triggerAlert("Alert"))
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    // Then: Should publish updates for each state change
    XCTAssertGreaterThanOrEqual(updateCount, 3, "Should publish for each state change")

    cancellable.cancel()
  }
}

#endif // canImport(SwiftUI) && canImport(Combine)
#endif // !os(Linux)
