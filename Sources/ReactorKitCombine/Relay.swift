//
//  Relay.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//
//  implementation borrows heavily from [CombineCommunity/CombineExt](https://github.com/CombineCommunity/CombineExt/blob/357e62bebcb2d64ac96dfe2233edb615f2714196/Sources/Relays/Relay.swift).
//

import Combine

/// A publisher that exposes a method for outside callers to publish values.
/// It is identical to a `Subject`, but it cannot publish a finish event (until it's deallocated).
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol Relay: Publisher where Failure == Never {
  associatedtype Output

  /// Relays a value to the subscriber.
  ///
  /// - Parameter value: The value to send.
  func accept(_ value: Output)

  /// Attaches the specified publisher to this relay.
  ///
  /// - parameter publisher: An infallible publisher with the relay's Output type
  ///
  /// - returns: `AnyCancellable`
  func subscribe<P: Publisher>(_ publisher: P) -> AnyCancellable where P.Failure == Failure, P.Output == Output
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher where Failure == Never {
  /// Attaches the specified relay to this publisher.
  ///
  /// - parameter relay: Relay to attach to this publisher
  ///
  /// - returns: `AnyCancellable`
  func subscribe<R: Relay>(_ relay: R) -> AnyCancellable where R.Output == Output {
    relay.subscribe(self)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Relay where Output == Void {
  /// Relay a void to the subscriber.
  func accept() {
    self.accept(())
  }
}
