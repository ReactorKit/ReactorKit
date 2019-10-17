//
//  ReactorEquatableTests.swift
//  ReactorKitTests
//
//  Created by Suyeol Jeon on 2019/10/17.
//

import XCTest
import ReactorKit
import RxSwift

final class ReactorEquatableTests: XCTestCase {
  func testReactorEqual_whenCurrentStatesAreEqual() {
    let reactorA = PostReactor(id: "a", viewCount: 0)
    let reactorB = PostReactor(id: "a", viewCount: 1)
    XCTAssertNotEqual(reactorA.currentState, reactorB.currentState)
    XCTAssertNotEqual(reactorA, reactorB)

    reactorA.action.onNext(.view)
    XCTAssertEqual(reactorA.currentState, reactorB.currentState)
    XCTAssertEqual(reactorA, reactorB)

    reactorA.action.onNext(.view)
    XCTAssertNotEqual(reactorA.currentState, reactorB.currentState)
    XCTAssertNotEqual(reactorA, reactorB)


    reactorB.action.onNext(.view)
    XCTAssertEqual(reactorA.currentState, reactorB.currentState)
    XCTAssertEqual(reactorA, reactorB)
  }
}

private final class PostReactor: Reactor, Equatable {
  enum Action {
    case view
  }

  enum Mutation {
    case increaseViewCount
  }

  struct State: Equatable {
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
