//
//  ReplaySubjectTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/07.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Tests/ReplaySubjectTests.swift).
//

import XCTest

import Combine
@testable import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ReplaySubjectTests: XCTestCase {
  private var subscriptions = Set<AnyCancellable>()

  private enum AnError: Error, Equatable {
    case someError
  }

  func testReplaysNoValues() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 1)

    var results = [Int]()

    subject
      .sink(receiveValue: { results.append($0) })
      .store(in: &subscriptions)

    XCTAssertTrue(results.isEmpty)
  }

  func testMissedValueWithEmptyBuffer() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 0)

    subject.send(1)

    var results = [Int]()

    subject
      .sink(receiveValue: { results.append($0) })
      .store(in: &subscriptions)

    subject.send(2)

    XCTAssertEqual(results, [2])
  }

  func testMissedValueWithSingleBuffer() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 1)

    subject.send(1)

    var results = [Int]()

    subject
      .sink(receiveValue: { results.append($0) })
      .store(in: &subscriptions)

    subject.send(2)

    XCTAssertEqual(results, [1, 2])
  }

  func testMissedValuesWithManyBuffer() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 3)

    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(4)

    var results = [Int]()

    subject
      .sink(receiveValue: { results.append($0) })
      .store(in: &subscriptions)

    subject.send(5)

    XCTAssertEqual(results, [2, 3, 4, 5])
  }

  func testMissedValuesWithManyBufferUnfilled() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 3)

    subject.send(1)
    subject.send(2)

    var results = [Int]()

    subject
      .sink(receiveValue: { results.append($0) })
      .store(in: &subscriptions)

    subject.send(3)

    XCTAssertEqual(results, [1, 2, 3])
  }

  func testMultipleSubscribers() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 3)

    subject.send(1)
    subject.send(2)

    var results1 = [Int]()
    var results2 = [Int]()
    var results3 = [Int]()

    subject
      .sink(receiveValue: { results1.append($0) })
      .store(in: &subscriptions)

    subject
      .sink(receiveValue: { results2.append($0) })
      .store(in: &subscriptions)

    subject
      .sink(receiveValue: { results3.append($0) })
      .store(in: &subscriptions)

    subject.send(3)

    XCTAssertEqual(results1, [1, 2, 3])
    XCTAssertEqual(results2, [1, 2, 3])
    XCTAssertEqual(results3, [1, 2, 3])
  }

  func testCompletionWithMultipleSubscribers() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 3)

    subject.send(1)
    subject.send(2)
    subject.send(completion: .finished)

    var results1 = [Int]()
    var completions1 = [Subscribers.Completion<Never>]()

    var results2 = [Int]()
    var completions2 = [Subscribers.Completion<Never>]()

    var results3 = [Int]()
    var completions3 = [Subscribers.Completion<Never>]()

    subject
      .sink(
        receiveCompletion: { completions1.append($0) },
        receiveValue: { results1.append($0) }
    )
      .store(in: &subscriptions)

    subject
      .sink(
        receiveCompletion: { completions2.append($0) },
        receiveValue: { results2.append($0) }
    )
      .store(in: &subscriptions)

    subject
      .sink(
        receiveCompletion: { completions3.append($0) },
        receiveValue: { results3.append($0) }
    )
      .store(in: &subscriptions)

    subject.send(3)

    XCTAssertEqual(results1, [1, 2])
    XCTAssertEqual(completions1, [.finished])

    XCTAssertEqual(results2, [1, 2])
    XCTAssertEqual(completions2, [.finished])

    XCTAssertEqual(results3, [1, 2])
    XCTAssertEqual(completions3, [.finished])
  }

  func testErrorWithMultipleSubscribers() {
    let subject = ReplaySubject<Int, AnError>(bufferSize: 3)

    subject.send(1)
    subject.send(2)
    subject.send(completion: .failure(.someError))

    var results1 = [Int]()
    var completions1 = [Subscribers.Completion<AnError>]()

    var results2 = [Int]()
    var completions2 = [Subscribers.Completion<AnError>]()

    var results3 = [Int]()
    var completions3 = [Subscribers.Completion<AnError>]()


    subject
      .sink(
        receiveCompletion: { completions1.append($0) },
        receiveValue: { results1.append($0) }
    )
      .store(in: &subscriptions)

    subject
      .sink(
        receiveCompletion: { completions2.append($0) },
        receiveValue: { results2.append($0) }
    )
      .store(in: &subscriptions)

    subject
      .sink(
        receiveCompletion: { completions3.append($0) },
        receiveValue: { results3.append($0) }
    )
      .store(in: &subscriptions)

    subject.send(3)

    XCTAssertEqual(results1, [1, 2])
    XCTAssertEqual(completions1, [.failure(.someError)])

    XCTAssertEqual(results2, [1, 2])
    XCTAssertEqual(completions2, [.failure(.someError)])

    XCTAssertEqual(results3, [1, 2])
    XCTAssertEqual(completions3, [.failure(.someError)])
  }

  func testValueAndCompletionPreSubscribe() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 1)

    subject.send(1)
    subject.send(completion: .finished)

    var results1 = [Int]()
    var completed = false

    subject
      .sink(
        receiveCompletion: { _ in completed = true },
        receiveValue: { results1.append($0) }
    )
      .store(in: &subscriptions)

    XCTAssertEqual(results1, [1])
    XCTAssertTrue(completed)
  }

  func testNoValuesReplayedPostCompletion() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 1)

    subject.send(1)
    subject.send(completion: .finished)
    subject.send(2)

    var results1 = [Int]()
    var completed = false

    subject
      .sink(
        receiveCompletion: { _ in completed = true },
        receiveValue: { results1.append($0) }
    )
      .store(in: &subscriptions)

    XCTAssertEqual(results1, [1])
    XCTAssertTrue(completed)
  }

  func testNoValuesReplayedPostError() {
    let subject = ReplaySubject<Int, AnError>(bufferSize: 1)

    subject.send(1)
    subject.send(completion: .failure(.someError))
    subject.send(2)

    var results1 = [Int]()
    var completed = false

    subject
      .sink(
        receiveCompletion: { _ in completed = true },
        receiveValue: { results1.append($0) }
    )
      .store(in: &subscriptions)

    XCTAssertEqual(results1, [1])
    XCTAssertTrue(completed)
  }

  private var demandSubscription: Subscription!
  func testRespectsDemand() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 4)

    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(4)

    var results = [Int]()
    var completed = false

    let subscriber = AnySubscriber<Int, Never>(
      receiveSubscription: { subscription in
        self.demandSubscription = subscription
        subscription.request(.max(3))
    },
      receiveValue: { results.append($0); return .none },
      receiveCompletion: { _ in completed = true }
    )

    subject
      .subscribe(subscriber)

    XCTAssertEqual(results, [1, 2, 3])
    XCTAssertFalse(completed)

    subject.send(completion: .finished)

    XCTAssertTrue(completed)
  }

  func testDoubleSubscribe() {
    let subject = ReplaySubject<Int, Never>(bufferSize: 1)

    subject.send(1)
    subject.send(2)
    subject.send(completion: .finished)

    var results = [String]()
    var completions = [Subscribers.Completion<Never>]()

    let subscriber = AnySubscriber<String, Never>(
      receiveSubscription: { $0.request(.max(1)) },
      receiveValue: { results.append($0); return .none },
      receiveCompletion: { completions.append($0) }
    )

    subject
      .map { "a\($0)" }
      .subscribe(subscriber)

    subject
      .map { "b\($0)" }
      .subscribe(subscriber)

    XCTAssertEqual(["a2", "b2"], results)
    XCTAssertEqual([.finished, .finished], completions)
  }
}
