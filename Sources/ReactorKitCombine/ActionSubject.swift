//
//  ActionSubject.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/25.
//

import Combine
import class Foundation.NSLock.NSRecursiveLock

/// A special subject for Reactor's Action. It only emits `.next` event.
@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public final class ActionSubject<Output>: Combine.Subject {

  public typealias Output = Output
  public typealias Failure = Swift.Never

  private let lock = NSRecursiveLock()
  var subscriptions: [CombineIdentifier: Subscription<Output, Failure>] = [:]

  public func send(_ value: Output) {
    self.lock.lock()
    let subscriptions = self.subscriptions
    self.lock.unlock()
    subscriptions.forEach { _, subscription in
      subscription.receive(value)
    }
  }

  public func send(completion: Combine.Subscribers.Completion<Failure>) {
    // ignore completion
  }

  public func send(subscription: Combine.Subscription) {
    subscription.request(.unlimited)
  }

  public func receive<Subscriber: Combine.Subscriber>(
    subscriber: Subscriber
  ) where Failure == Subscriber.Failure, Output == Subscriber.Input {
    let subscription = Subscription(
      subscriber: subscriber,
      cancelHandler: { [weak self] subscription in
        guard let self = self else { return }
        self.lock.lock(); defer { self.lock.unlock() }
        self.subscriptions.removeValue(forKey: subscription.combineIdentifier)
      }
    )
    subscriber.receive(subscription: subscription)
    self.lock.lock()
    self.subscriptions[subscription.combineIdentifier] = subscription
    self.lock.unlock()
  }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension ActionSubject {
  final class Subscription<Output, Failure: Error>: Combine.Subscription {

    typealias Output = Output
    typealias Failure = Swift.Never

    private let lock = NSRecursiveLock()
    private let subscriber: Combine.AnySubscriber<Output, Failure>
    private var demand: Combine.Subscribers.Demand = .none
    private var cancelHandler: (Subscription<Output, Failure>) -> Void

    init<Subscriber: Combine.Subscriber>(
      subscriber: Subscriber,
      cancelHandler: @escaping (Subscription<Output, Failure>) -> Void
    ) where Output == Subscriber.Input, Failure == Subscriber.Failure {
      self.subscriber = Combine.AnySubscriber<Output, Failure>(subscriber)
      self.cancelHandler = cancelHandler
    }

    func request(_ demand: Combine.Subscribers.Demand) {
      self.lock.lock(); defer { self.lock.unlock() }
      self.demand += demand
    }

    func cancel() {
      self.lock.lock(); defer { self.lock.unlock() }
      self.cancelHandler(self)
    }

    func receive(_ value: Output) {
      self.lock.lock(); defer { self.lock.unlock() }
      guard self.demand > .none else { return }
      self.demand -= 1
      self.demand += self.subscriber.receive(value)
    }
  }
}
