//
//  IdentityEquatableTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/06.
//

import XCTest

import ReactorKitCombine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class IdentityEquatableTests: XCTestCase {
  func testReactorEqual_whenCurrentStatesAreEqual() {
    let reactorA = SimpleReactor()
    let reactorB = reactorA
    XCTAssertEqual(reactorA, reactorB)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class SimpleReactor: Reactor, IdentityEquatable {
  typealias Action = Never
  typealias Mutation = Never
  struct State {
  }

  let initialState = State()
}
