//
//  IdentityHashableTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest
import ReactorKit
import RxSwift

final class IdentityHashableTests: XCTestCase {
  func testReactorHashValue() {
    let reactorA = SimpleReactor()
    let reactorB = reactorA
    XCTAssertEqual(reactorA.hashValue, reactorB.hashValue)
    XCTAssertEqual(reactorA, reactorB)
  }
}

private final class SimpleReactor: Reactor, IdentityHashable {
  typealias Action = Never
  typealias Mutation = Never
  struct State {
  }

  let initialState = State()
}
