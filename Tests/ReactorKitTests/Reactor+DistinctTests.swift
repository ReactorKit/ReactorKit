//
//  Reactor+DistinctTests.swift
//  ReactorKitTests
//
//  Created by Haeseok Lee on 2022/03/20.
//

import XCTest
import RxSwift
@testable import ReactorKit

final class Reactor_DistinctTests: XCTestCase {
  
  func testDistinct() {
    // given
    let reactor = TestReactor(section: Section(items: ["a", "b", "c"]))
    let disposeBag = DisposeBag()
    var sectionUpdatedCounter = 0
    var titleUpdatedCounter = 0
    
    reactor.state(\.$section)
      .subscribe(onNext: { section in
        sectionUpdatedCounter += 1
      })
      .disposed(by: disposeBag)
    
    reactor.state(\.$title)
      .subscribe(onNext: { title in
        titleUpdatedCounter += 1
      })
      .disposed(by: disposeBag)
    
    // when
    reactor.action.onNext(.updateSectionItems(["a", "b", "c"])) // don't render section
    reactor.action.onNext(.increaseCount)                       // don't render section & title
    reactor.action.onNext(.updateSectionItems(["a"]))           // render section
    reactor.action.onNext(.updateSectionItems(["a"]))           // don't render section
    
    reactor.action.onNext(.updateTitle("title"))                // render title
    reactor.action.onNext(.updateTitle("new title"))            // render title
    reactor.action.onNext(.increaseCount)                       // don't render section & title
    reactor.action.onNext(.updateTitle("new title"))            // don't render title

    // then
    XCTAssertEqual(sectionUpdatedCounter, 2)                    // first section rendering + 1
    XCTAssertEqual(titleUpdatedCounter, 3)                      // first title rendering + 2
    
    XCTAssertEqual(reactor.currentState.section.items, ["a"])
    XCTAssertEqual(reactor.currentState.title, "new title")
    XCTAssertEqual(reactor.currentState.count, 2)
  }
}

fileprivate final class TestReactor: Reactor {
  
  enum Action {
    case updateSectionItems([Section.Item])
    case updateTitle(String)
    case increaseCount
  }

  enum Mutation {
    case setSectionItems([Section.Item])
    case setTitle(String)
    case increaseCount
  }

  struct State {
    @Distinct var section: Section
    @Distinct var title: String?
    var count: Int = 0
  }

  let initialState: State
  
  init(section: Section) {
    initialState = State(section: section)
  }
  
  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .updateSectionItems(items):
      return Observable.just(Mutation.setSectionItems(items))
    case let .updateTitle(title):
      return Observable.just(Mutation.setTitle(title))
    case .increaseCount:
      return Observable.just(Mutation.increaseCount)
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
    case let .setSectionItems(items):
      newState.section.items = items
    case let .setTitle(title):
      newState.title = title
    case .increaseCount:
      newState.count += 1
    }

    return newState
  }
}

fileprivate class Section: Hashable {
  
  typealias Item = String
  
  static func == (lhs: Section, rhs: Section) -> Bool {
    lhs.hashValue == rhs.hashValue
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(items)
  }
  
  var items: [Item]
  
  init(items: [Item]) {
    self.items = items
  }
}
