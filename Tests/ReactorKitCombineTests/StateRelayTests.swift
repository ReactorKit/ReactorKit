//
//  StateRelayTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/06.
//

import XCTest

import Combine
@testable import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class StateRelayTests: XCTestCase {
  func testInitialValue() {
    let relay = StateRelay("initial")
    XCTAssertEqual(relay.value, "initial")
  }

  func testValueGetter() {
    // given
    let relay = StateRelay("")

    // when & then
    relay.accept("second")
    XCTAssertEqual(relay.value, "second")

    relay.accept("third")
    XCTAssertEqual(relay.value, "third")
  }

  func testValueSetter() {
    // given
    let relay = StateRelay("")

    // when & then
    relay.value = "second"
    XCTAssertEqual(relay.value, "second")

    relay.value = "third"
    XCTAssertEqual(relay.value, "third")
  }

  func testAccept() {
    // given
    let relay = StateRelay(0)

    // when & then
    relay.accept(100)
    XCTAssertEqual(relay.value, 100)

    relay.accept(200)
    XCTAssertEqual(relay.value, 200)

    relay.accept(300)
    XCTAssertEqual(relay.value, 300)
  }

  func testFinishesOnDeinit() {
    // given
    var relay: StateRelay<Void>? = StateRelay(Void())
    var cancellables: Set<AnyCancellable> = []

    var isCompleted = false
    relay?
      .sink(
        receiveCompletion: { _ in isCompleted = true },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    XCTAssertFalse(isCompleted)

    // when
    relay = nil

    // then
    XCTAssertTrue(isCompleted)
  }

  func testReplaysCurrentValue() {
    // given
    let relay = StateRelay("initial")
    var cancellables: Set<AnyCancellable> = []

    var receivedValues: [String] = []
    relay
      .sink(receiveValue: { receivedValues.append($0) })
      .store(in: &cancellables)
    XCTAssertEqual(receivedValues, ["initial"])

    relay.accept("yo")
    XCTAssertEqual(receivedValues, ["initial", "yo"])

    // when
    var secondReceivedValues: [String] = []
    relay.sink(receiveValue: { secondReceivedValues.append($0) }).store(in: &cancellables)

    // then
    XCTAssertEqual(secondReceivedValues, ["yo"])
  }

  func testSubscribePublisher() {
    // given
    let relay = StateRelay("initial")
    var cancellables: Set<AnyCancellable> = []

    var isCompleted = false
    var receivedValues: [String] = []
    relay
      .sink(
        receiveCompletion: { _ in isCompleted = true },
        receiveValue: { receivedValues.append($0) }
      )
      .store(in: &cancellables)

    // when
    ["1", "2", "3"]
      .publisher
      .subscribe(relay)
      .store(in: &cancellables)

    // then
    XCTAssertFalse(isCompleted)
    XCTAssertEqual(receivedValues, ["initial", "1", "2", "3"])
  }
}
