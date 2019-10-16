//
//  ReactorHashableTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest
import ReactorKit
import RxSwift

final class ReactorHashableTests: XCTestCase {
  func testReactorHashValue() {
    let reactorA = PostReactor(id: "a", viewCount: 0)
    let reactorB = PostReactor(id: "a", viewCount: 1)
    XCTAssertNotEqual(reactorA.currentState.hashValue, reactorB.currentState.hashValue)
    XCTAssertNotEqual(reactorA.hashValue, reactorB.hashValue)

    reactorA.action.onNext(.view)
    XCTAssertEqual(reactorA.currentState.hashValue, reactorB.currentState.hashValue)
    XCTAssertEqual(reactorA.hashValue, reactorB.hashValue)

    reactorA.action.onNext(.view)
    XCTAssertNotEqual(reactorA.currentState.hashValue, reactorB.currentState.hashValue)
    XCTAssertNotEqual(reactorA.hashValue, reactorB.hashValue)


    reactorB.action.onNext(.view)
    XCTAssertEqual(reactorA.currentState.hashValue, reactorB.currentState.hashValue)
    XCTAssertEqual(reactorA.hashValue, reactorB.hashValue)
  }
}

private final class PostReactor: Reactor, Hashable {
  enum Action {
    case view
  }

  enum Mutation {
    case increaseViewCount
  }

  struct State: Hashable {
    var id: String
    var viewCount: Int
  }

  let initialState: State

  init(id: String, viewCount: Int) {
    self.initialState = State(id: id, viewCount: viewCount)
  }

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .view:
      return .just(.increaseViewCount)
    }
  }

  func reduce(state: State, mutation: Mutation) -> PostReactor.State {
    var newState = state
    switch mutation {
    case .increaseViewCount:
      newState.viewCount += 1
    }
    return newState
  }
}
