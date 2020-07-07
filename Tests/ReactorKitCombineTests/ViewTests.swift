
//
//  StateRelayTests.swift
//  ReactorKitCombineTests
//
//  Created by tokijh on 2020/07/06.
//

import XCTest

import Combine
import ReactorKitCombine

#if os(iOS) || os(tvOS)
import UIKit
private typealias OSViewController = UIViewController
private typealias OSView = UIView
#elseif os(OSX)
import AppKit
private typealias OSViewController = NSViewController
private typealias OSView = NSView
#endif

#if !os(Linux)
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ViewTests: XCTestCase {
  func testBindIsInvoked_differentReactor() {
    // given
    let view = TestView()

    // when & then
    XCTAssertEqual(view.bindInvokeCount, 0)

    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 1)

    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 2)
  }

  func testClearCancellablesWhenSetDifferentReactor() {
    // given
    let view = TestView()

    // when & then
    XCTAssertTrue(view.cancellables.isEmpty)

    let oldHashValue = view.cancellables
    view.reactor = TestReactor()
    XCTAssertFalse(view.cancellables.isEmpty)

    let newHashValue = view.cancellables
    view.reactor = TestReactor()
    XCTAssertFalse(view.cancellables.isEmpty)

    XCTAssertNotEqual(oldHashValue, newHashValue)
  }

  func testReactor_assign() {
    // given
    let reactor = TestReactor()
    let view = TestView()

    // when
    view.reactor = reactor

    // then
    XCTAssertNotNil(view.reactor)
    XCTAssertTrue(view.reactor === reactor)
  }

  func testReactor_assignNil() {
    // given
    let reactor = TestReactor()
    let view = TestView()
    view.reactor = reactor

    // when
    view.reactor = nil

    // then
    XCTAssertNil(view.reactor)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class TestView: View {
  var cancellables: Set<AnyCancellable> = []
  var bindInvokeCount = 0

  func bind(reactor: TestReactor) {
    self.bindInvokeCount += 1
    reactor.state.sink(receiveValue: { _ in }).store(in: &self.cancellables)
  }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class TestReactor: Reactor {
  typealias Action = Never
  struct State {}
  let initialState = State()
}
#endif
