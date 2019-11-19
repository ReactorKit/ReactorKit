//
//  IdentityEquatableTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest
import ReactorKit
import RxSwift

final class IdentityEquatableTests: XCTestCase {
  func testReactorEqual_whenCurrentStatesAreEqual() {
    let reactorA = SimpleReactor()
    let reactorB = reactorA
    XCTAssertEqual(reactorA, reactorB)
  }
}

private final class SimpleReactor: Reactor, IdentityEquatable {
  typealias Action = Never
  typealias Mutation = Never
  struct State {
  }

  let initialState = State()
}
