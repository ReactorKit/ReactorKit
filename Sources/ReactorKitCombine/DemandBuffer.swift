//
//  DemandBuffer.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Sources/Common/DemandBuffer.swift).
//

import Combine
import class Foundation.NSRecursiveLock

/// A buffer responsible for managing the demand of a downstream
/// subscriber for an upstream publisher
///
/// It buffers values and completion events and forwards them dynamically
/// according to the demand requested by the downstream
///
/// In a sense, the subscription only relays the requests for demand, as well
/// the events emitted by the upstream — to this buffer, which manages
/// the entire behavior and backpressure contract
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class DemandBuffer<S: Subscriber> {
  private let lock = NSRecursiveLock()
  private var buffer = [S.Input]()
  private let subscriber: S
  private var completion: Subscribers.Completion<S.Failure>?
  private var demandState = Demand()

  /// Initialize a new demand buffer for a provided downstream subscriber
  ///
  /// - parameter subscriber: The downstream subscriber demanding events
  init(subscriber: S) {
    self.subscriber = subscriber
  }

  /// Buffer an upstream value to later be forwarded to
  /// the downstream subscriber, once it demands it
  ///
  /// - parameter value: Upstream value to buffer
  ///
  /// - returns: The demand fulfilled by the bufferr
  func buffer(value: S.Input) -> Subscribers.Demand {
    precondition(self.completion == nil, "How could a completed publisher sent values?! Beats me 🤷‍♂️")

    switch self.demandState.requested {
    case .unlimited:
      return self.subscriber.receive(value)

    default:
      self.buffer.append(value)
      return self.flush()
    }
  }

  /// Complete the demand buffer with an upstream completion event
  ///
  /// This method will deplete the buffer immediately,
  /// based on the currently accumulated demand, and relay the
  /// completion event down as soon as demand is fulfilled
  ///
  /// - parameter completion: Completion event
  func complete(completion: Subscribers.Completion<S.Failure>) {
    precondition(self.completion == nil, "Completion have already occured, which is quite awkward 🥺")

    self.completion = completion
    _ = self.flush()
  }

  /// Signal to the buffer that the downstream requested new demand
  ///
  /// - note: The buffer will attempt to flush as many events rqeuested
  ///         by the downstream at this point
  func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
    self.flush(adding: demand)
  }

  /// Flush buffered events to the downstream based on the current
  /// state of the downstream's demand
  ///
  /// - parameter newDemand: The new demand to add. If `nil`, the flush isn't the
  ///                        result of an explicit demand change
  ///
  /// - note: After fulfilling the downstream's request, if completion
  ///         has already occured, the buffer will be cleared and the
  ///         completion event will be sent to the downstream subscriber
  private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
    self.lock.lock()
    defer { self.lock.unlock() }

    if let newDemand = newDemand {
      self.demandState.requested += newDemand
    }

    // If buffer isn't ready for flushing, return immediately
    guard self.demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }

    while !self.buffer.isEmpty && self.demandState.processed < self.demandState.requested {
      self.demandState.requested += self.subscriber.receive(self.buffer.remove(at: 0))
      self.demandState.processed += 1
    }

    if let completion = self.completion {
      // Completion event was already sent
      self.buffer = []
      self.demandState = .init()
      self.completion = nil
      self.subscriber.receive(completion: completion)
      return .none
    }

    let sentDemand = self.demandState.requested - self.demandState.sent
    self.demandState.sent += sentDemand
    return sentDemand
  }
}

// MARK: - Private Helpers
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension DemandBuffer {
  /// A model that tracks the downstream's
  /// accumulated demand state
  struct Demand {
    var processed: Subscribers.Demand = .none
    var requested: Subscribers.Demand = .none
    var sent: Subscribers.Demand = .none
  }
}

// MARK: - Internally-scoped helpers
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Subscription {
  /// Reqeust demand if it's not empty
  ///
  /// - parameter demand: Requested demand
  func requestIfNeeded(_ demand: Subscribers.Demand) {
    guard demand > .none else { return }
    self.request(demand)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Optional where Wrapped == Subscription {
  /// Cancel the Optional subscription and nullify it
  mutating func kill() {
    self?.cancel()
    self = nil
  }
}
