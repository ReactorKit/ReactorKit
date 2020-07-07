//
//  ActionSubjectTests.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/25.
//

import XCTest

import Combine
@testable import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ActionSubjectTests: XCTestCase {
  func testObserversCount_disposable() {
    let subject = ActionSubject<Int>()
    let cancellable1 = subject.sink(receiveValue: { _ in })
    XCTAssertEqual(subject.subscriptions.count, 1)
    let cancellable2 = subject.sink(receiveValue: { _ in })
    XCTAssertEqual(subject.subscriptions.count, 2)
    cancellable1.cancel()
    XCTAssertEqual(subject.subscriptions.count, 1)
    cancellable2.cancel()
    XCTAssertEqual(subject.subscriptions.count, 0)
  }

  func testEmitNexts() {
    // given
    let subject = ActionSubject<Int>()

    var cancellables: Set<AnyCancellable> = []
    var latestValue: Int?
    subject.sink { latestValue = $0 }.store(in: &cancellables)

    // when & then
    subject.send(100)
    XCTAssertEqual(latestValue, 100)

    subject.send(200)
    XCTAssertEqual(latestValue, 200)

    subject.send(300)
    XCTAssertEqual(latestValue, 300)
  }

  func testIgnoreCompleted() {
    // given
    let subject = ActionSubject<Int>()

    var cancellables: Set<AnyCancellable> = []
    var receivedCompletions: [Subscribers.Completion<Never>] = []
    var receivedValues: [Int] = []
    subject
      .sink(
        receiveCompletion: { receivedCompletions.append($0) },
        receiveValue: { receivedValues.append($0) }
      )
      .store(in: &cancellables)

    // when & then
    subject.send(100)
    XCTAssertEqual(receivedCompletions.count, 0)
    XCTAssertEqual(receivedValues, [100])

    subject.send(completion: .finished)
    XCTAssertEqual(receivedCompletions.count, 0)
    XCTAssertEqual(receivedValues, [100])

    subject.send(200)
    XCTAssertEqual(receivedCompletions.count, 0)
    XCTAssertEqual(receivedValues, [100, 200])
  }
}
