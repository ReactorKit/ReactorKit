//
//  IdentityHashableTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/06.
//

import XCTest

import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class IdentityHashableTests: XCTestCase {
  func testReactorHashValue() {
    let reactorA = SimpleReactor()
    let reactorB = reactorA
    XCTAssertEqual(reactorA.hashValue, reactorB.hashValue)
    XCTAssertEqual(reactorA, reactorB)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class SimpleReactor: Reactor, IdentityHashable {
  typealias Action = Never
  typealias Mutation = Never
  struct State {
  }

  let initialState = State()
}
