//
//  Sink.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Sources/Common/Sink.swift).
//

import Combine

/// A generic sink using an underlying demand buffer to balance
/// the demand of a downstream subscriber for the events of an
/// upstream publisher
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class Sink<Upstream: Publisher, Downstream: Subscriber>: Subscriber {
  typealias TransformFailure = (Upstream.Failure) -> Downstream.Failure?
  typealias TransformOutput = (Upstream.Output) -> Downstream.Input?

  private(set) var buffer: DemandBuffer<Downstream>
  private var upstreamSubscription: Subscription?
  private let transformOutput: TransformOutput?
  private let transformFailure: TransformFailure?

  /// Initialize a new sink subscribing to the upstream publisher and
  /// fulfilling the demand of the downstream subscriber using a backpresurre
  /// demand-maintaining buffer.
  ///
  /// - parameter upstream: The upstream publisher
  /// - parameter downstream: The downstream subscriber
  /// - parameter transformOutput: Transform the upstream publisher's output type to the downstream's input type
  /// - parameter transformFailure: Transform the upstream failure type to the downstream's failure type
  ///
  /// - note: You **must** provide the two transformation functions above if you're using
  ///         the default `Sink` implementation. Otherwise, you must subclass `Sink` with your own
  ///         publisher's sink and manage the buffer accordingly.
  init(upstream: Upstream,
       downstream: Downstream,
       transformOutput: TransformOutput? = nil,
       transformFailure: TransformFailure? = nil) {
    self.buffer = DemandBuffer(subscriber: downstream)
    self.transformOutput = transformOutput
    self.transformFailure = transformFailure
    upstream.subscribe(self)
  }

  func demand(_ demand: Subscribers.Demand) {
    let newDemand = self.buffer.demand(demand)
    self.upstreamSubscription?.requestIfNeeded(newDemand)
  }

  func receive(subscription: Subscription) {
    self.upstreamSubscription = subscription
  }

  func receive(_ input: Upstream.Output) -> Subscribers.Demand {
    guard let transform = self.transformOutput else {
      fatalError(
        """
        ❌ Missing output transformation
        =========================
        You must either:
            - Provide a transformation function from the upstream's output to the downstream's input; or
            - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
        """
      )
    }

    guard let input = transform(input) else { return .none }
    return self.buffer.buffer(value: input)
  }

  func receive(completion: Subscribers.Completion<Upstream.Failure>) {
    switch completion {
    case .finished:
      self.buffer.complete(completion: .finished)
    case .failure(let error):
      guard let transform = self.transformFailure else {
        fatalError(
          """
          ❌ Missing failure transformation
          =========================
          You must either:
              - Provide a transformation function from the upstream's failure to the downstream's failuer; or
              - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
          """
        )
      }

      guard let error = transform(error) else { return }
      self.buffer.complete(completion: .failure(error))
    }

    self.cancelUpstream()
  }

  func cancelUpstream() {
    self.upstreamSubscription.kill()
  }

  deinit { self.cancelUpstream() }
}
