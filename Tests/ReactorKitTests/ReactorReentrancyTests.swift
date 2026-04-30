//
//  ReactorReentrancyTests.swift
//  ReactorKit
//
//  Created by Kanghoon Oh on 4/30/26.
//

import XCTest

import ReactorKit
@preconcurrency import RxSwift

@preconcurrency
final class ReactorReentrancyTests: XCTestCase {

  func test_reentrantActionFromStateSubscriber_isSerialized() {
    final class LogReactor: Reactor, @unchecked Sendable {
      enum Action {
        case a
        case b
      }

      enum Mutation {
        case enterA
        case exitA
        case enterB
        case exitB
      }

      struct State {
        var log: [String] = []
      }

      let initialState = State()

      func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .a:
          return .from([.enterA, .exitA])
        case .b:
          return .from([.enterB, .exitB])
        }
      }

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .enterA: newState.log.append("enter A")
        case .exitA: newState.log.append("exit A")
        case .enterB: newState.log.append("enter B")
        case .exitB: newState.log.append("exit B")
        }
        return newState
      }
    }

    let reactor = LogReactor()
    let disposeBag = DisposeBag()
    var didDispatchB = false

    reactor.state
      .subscribe(onNext: { state in
        if !didDispatchB && state.log.contains("enter A") {
          didDispatchB = true
          reactor.action.onNext(.b)
        }
      })
      .disposed(by: disposeBag)

    reactor.action.onNext(.a)

    XCTAssertEqual(
      reactor.currentState.log,
      ["enter A", "exit A", "enter B", "exit B"]
    )
  }

  func test_reentrantActionFromReduce_doesNotRecurse() {
    final class LogReactor: Reactor, @unchecked Sendable {
      enum Action {
        case a
        case b
      }

      enum Mutation {
        case enterA
        case exitA
        case enterB
        case exitB
      }

      struct State {
        var log: [String] = []
      }

      let initialState = State()
      private var didTriggerFollowUp = false

      func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .a:
          return .from([.enterA, .exitA])
        case .b:
          return .from([.enterB, .exitB])
        }
      }

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .enterA:
          newState.log.append("enter A")
          if !didTriggerFollowUp {
            didTriggerFollowUp = true
            action.onNext(.b)
          }
        case .exitA: newState.log.append("exit A")
        case .enterB: newState.log.append("enter B")
        case .exitB: newState.log.append("exit B")
        }
        return newState
      }
    }

    let reactor = LogReactor()
    _ = reactor.state.subscribe()

    reactor.action.onNext(.a)

    XCTAssertEqual(
      reactor.currentState.log,
      ["enter A", "exit A", "enter B", "exit B"]
    )
  }

  func test_dismissThenPresent_routingPattern() {
    final class RouteReactor: Reactor, @unchecked Sendable {
      enum Action {
        case dismiss
        case present(String)
      }

      enum Mutation {
        case setRoute(String?)
      }

      struct State {
        var route: String?
      }

      let initialState = State(route: "initial")

      func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .dismiss:
          return .just(.setRoute(nil))
        case .present(let route):
          return .just(.setRoute(route))
        }
      }

      func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setRoute(let route):
          newState.route = route
        }
        return newState
      }
    }

    let reactor = RouteReactor()
    let disposeBag = DisposeBag()
    var didPresent = false

    reactor.state
      .subscribe(onNext: { state in
        if !didPresent && state.route == nil {
          didPresent = true
          reactor.action.onNext(.present("next"))
        }
      })
      .disposed(by: disposeBag)

    reactor.action.onNext(.dismiss)

    XCTAssertEqual(reactor.currentState.route, "next")
  }
}
