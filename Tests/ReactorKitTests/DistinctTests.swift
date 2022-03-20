//
//  DistinctTests.swift
//  ReactorKitTests
//
//  Created by Haeseok Lee on 2022/03/20.
//

import XCTest
import RxSwift
@testable import ReactorKit

final class DistinctTests: XCTestCase {
  func testIsDirtyIsTrueWhenFirstLoaded() {
    // given
    struct State {
      @Distinct var value: Int = 0
    }

    // when
    let state = State()
    
    // then
    XCTAssertTrue(state.$value.isDirty)
  }

  func testIsDirtyIsTrueWhenNewValueAssigned() {
    // given
    struct State {
      @Distinct var value: Int = 0
    }
    
    // when & then
    var state = State()
    state.value = 10 // assign new value
    XCTAssertTrue(state.$value.isDirty)
    
    state.value = 20 // assign new value
    XCTAssertTrue(state.$value.isDirty)
    
    state.value = 30 // assign new value
    XCTAssertTrue(state.$value.isDirty)
    
  }
  
  func testIsDirtyIsFalseWhenSameValueAssigned() {
    // given
    struct State {
      @Distinct var value: Int = 0
    }
    
    // when & then
    var state = State()
    state.value = 10 // assign new value
    XCTAssertTrue(state.$value.isDirty)
    
    state.value = 10 // assign same value
    XCTAssertFalse(state.$value.isDirty)
    
    state.value = 10 // assign same value
    XCTAssertFalse(state.$value.isDirty)
  }
}
