//
//  StateRelay.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/07/06.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Sources/Relays/CurrentValueRelay.swift).
//

import Combine

/// A relay that wraps a single value and publishes a new element whenever the value changes.
///
/// Unlike its subject-counterpart, it may only accept values, and only sends a finishing event on deallocation.
/// It cannot send a failure event.
///
/// - note: Unlike PassthroughRelay, CurrentValueRelay maintains a buffer of the most recently published value.
///
/// StateRelay is a wrapper for `BehaviorSubject`.
///
/// Unlike `BehaviorSubject` it can't terminate with error or completed.
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class StateRelay<Output>: Relay {

  private let storage: CurrentValueSubject<Output, Never>
  private var subscriptions: [Subscription<CurrentValueSubject<Output, Never>, AnySubscriber<Output, Never>>] = []

  public var value: Output {
    get { return self.storage.value }
    set { self.accept(newValue) }
  }

  /// Create a new relay
  ///
  /// - parameter value: Initial value for the relay
  public init(_ value: Output) {
    self.storage = .init(value)
  }

  /// Relay a value to downstream subscribers
  ///
  /// - parameter value: A new value
  public func accept(_ value: Output) {
    self.storage.send(value)
  }

  public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Never == S.Failure {
    let subscription = Subscription(upstream: self.storage, downstream: AnySubscriber(subscriber))
    self.subscriptions.append(subscription)
    subscriber.receive(subscription: subscription)
  }

  public func subscribe<P: Publisher>(_ publisher: P) -> AnyCancellable where Output == P.Output, P.Failure == Never {
    publisher.subscribe(self.storage)
  }

  deinit {
    // Send a finished event upon dealloation
    self.subscriptions.forEach { $0.forceFinish() }
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension StateRelay {
  class Subscription<Upstream: Publisher, Downstream: Subscriber>: Combine.Subscription where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {

    private var sink: Sink<Upstream, Downstream>?
    var shouldForwardCompletion: Bool {
      get { self.sink?.shouldForwardCompletion ?? false }
      set { self.sink?.shouldForwardCompletion = newValue }
    }

    init(upstream: Upstream,
         downstream: Downstream) {
      self.sink = Sink(
        upstream: upstream,
        downstream: downstream,
        transformOutput: { $0 }
      )
    }

    func forceFinish() {
      self.sink?.shouldForwardCompletion = true
      self.sink?.receive(completion: .finished)
    }

    func request(_ demand: Subscribers.Demand) {
      self.sink?.demand(demand)
    }

    func cancel() {
      self.sink = nil
    }
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension StateRelay {
  class Sink<Upstream: Publisher, Downstream: Subscriber>: ReactorKitCombine.Sink<Upstream, Downstream> {
    var shouldForwardCompletion = false
    override func receive(completion: Subscribers.Completion<Upstream.Failure>) {
      guard self.shouldForwardCompletion else { return }
      super.receive(completion: completion)
    }
  }
}
