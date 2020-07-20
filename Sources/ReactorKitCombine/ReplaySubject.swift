//
//  ReplaySubject.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Sources/Subjects/ReplaySubject.swift).
//

import Combine

/// A `ReplaySubject` is a subject that can buffer one or more values. It stores value events, up to its `bufferSize` in a
/// first-in-first-out manner and then replays it to
/// future subscribers and also forwards completion events.
///
/// The implementation borrows heavily from [Entwine’s](https://github.com/tcldr/Entwine/blob/b839c9fcc7466878d6a823677ce608da998b95b9/Sources/Entwine/Operators/ReplaySubject.swift).
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ReplaySubject<Output, Failure: Error>: Subject {
  typealias Output = Output
  typealias Failure = Failure

  private let bufferSize: Int
  private var buffer = [Output]()

  // Keeping track of all live subscriptions, so `send` events can be forwarded to them.
  private var subscriptions = [Subscription<AnySubscriber<Output, Failure>>]()

  private var completion: Subscribers.Completion<Failure>?
  private var isActive: Bool { self.completion == nil }

  /// Create a `ReplaySubject`, buffering up to `bufferSize` values and replaying them to new subscribers
  /// - Parameter bufferSize: The maximum number of value events to buffer and replay to all future subscribers.
  init(bufferSize: Int) {
    self.bufferSize = bufferSize
  }

  func send(_ value: Output) {
    guard self.isActive else { return }

    self.buffer.append(value)

    if self.buffer.count > self.bufferSize {
      self.buffer.removeFirst()
    }

    self.subscriptions.forEach { $0.forwardValueToBuffer(value) }
  }

  func send(completion: Subscribers.Completion<Failure>) {
    guard self.isActive else { return }

    self.completion = completion

    self.subscriptions.forEach { $0.forwardCompletionToBuffer(completion) }
  }

  func send(subscription: Combine.Subscription) {
    subscription.request(.unlimited)
  }

  func receive<Subscriber: Combine.Subscriber>(subscriber: Subscriber) where Failure == Subscriber.Failure, Output == Subscriber.Input {
    let subscriberIdentifier = subscriber.combineIdentifier

    let subscription = Subscription(downstream: AnySubscriber(subscriber)) { [weak self] in
      let isEqualToSubscriber: (Subscription<AnySubscriber<Output, Failure>>) -> Bool = {
        $0.innerSubscriberIdentifier == subscriberIdentifier
      }
      guard let subscriptionIndex = self?.subscriptions.firstIndex(where: isEqualToSubscriber) else { return }

      self?.subscriptions.remove(at: subscriptionIndex)
    }

    self.subscriptions.append(subscription)

    subscriber.receive(subscription: subscription)
    subscription.replay(self.buffer, completion: self.completion)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ReplaySubject {
  final class Subscription<Downstream: Subscriber>: Combine.Subscription where Output == Downstream.Input, Failure == Downstream.Failure {
    private var demandBuffer: DemandBuffer<Downstream>?
    private var cancellationHandler: (() -> Void)?

    fileprivate let innerSubscriberIdentifier: CombineIdentifier

    init(downstream: Downstream, cancellationHandler: (() -> Void)?) {
      self.demandBuffer = DemandBuffer(subscriber: downstream)
      self.innerSubscriberIdentifier = downstream.combineIdentifier
      self.cancellationHandler = cancellationHandler
    }

    func replay(_ buffer: [Output], completion: Subscribers.Completion<Failure>?) {
      buffer.forEach(self.forwardValueToBuffer)

      if let completion = completion {
        self.forwardCompletionToBuffer(completion)
      }
    }

    func forwardValueToBuffer(_ value: Output) {
      _ = self.demandBuffer?.buffer(value: value)
    }

    func forwardCompletionToBuffer(_ completion: Subscribers.Completion<Failure>) {
      self.demandBuffer?.complete(completion: completion)
    }

    func request(_ demand: Subscribers.Demand) {
      _ = self.demandBuffer?.demand(demand)
    }

    func cancel() {
      self.cancellationHandler?()
      self.cancellationHandler = nil

      self.demandBuffer = nil
    }
  }
}
