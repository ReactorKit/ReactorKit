//
//  SignalTests.swift
//  ReactorKitTests
//
//  Created by 윤중현 on 2021/01/10.
//

import XCTest
import RxSwift
@testable import ReactorKit

final class SignalTests: XCTestCase {
  func testRiseValueUpdatedCountWhenSetNewValue() {
    // given
    struct State {
      @Signal var value: Int = 0
    }

    var state = State()

    // when & then
    XCTAssertEqual(state.$value.valueUpdatedCount, 0)
    state.value = 10
    XCTAssertEqual(state.$value.valueUpdatedCount, 1)
    XCTAssertEqual(state.$value.valueUpdatedCount, 1) // same count because no new values are assigned.
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 2)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 3)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 4)
    XCTAssertEqual(state.$value.valueUpdatedCount, 4) // same count because no new values are assigned.
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 5)
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 6)
  }

  func testSet0WhenValueUpdatedCountIsOverflowed() {
    // given
    var signal = Signal<Int>(wrappedValue: 0)

    // make to full
    signal.valueUpdatedCount = UInt.max
    XCTAssertEqual(signal.valueUpdatedCount, UInt.max)

    // when & then
    signal.value = 1 // when valueUpdatedCount is overflowed
    XCTAssertEqual(signal.valueUpdatedCount, 0)

    signal.value = 2
    XCTAssertEqual(signal.valueUpdatedCount, 1)
  }
}
