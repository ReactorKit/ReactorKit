import XCTest
import RxExpect
import RxSwift
import RxTest
@testable import ReactorKit

final class ActionSubjectTests: XCTestCase {
  func testObserversCount_disposable() {
    let subject = ActionSubject<Int>()
    let disposable1 = subject.subscribe()
    XCTAssertEqual(subject.observers.count, 1)
    let disposable2 = subject.subscribe()
    XCTAssertEqual(subject.observers.count, 2)
    disposable2.dispose()
    XCTAssertEqual(subject.observers.count, 1)
    disposable1.dispose()
    XCTAssertEqual(subject.observers.count, 0)
  }

  func testEmitNexts() {
    let test = RxExpect()
    let subject = ActionSubject<Int>()
    test.input(subject, [
      next(100, 1),
      next(200, 2),
      next(300, 3),
    ])
    test.assert(subject) { events in
      XCTAssertEqual(events, [
        next(100, 1),
        next(200, 2),
        next(300, 3),
      ])
    }
  }

  func testIgnoreError() {
    let test = RxExpect()
    let subject = ActionSubject<Int>()
    test.input(subject, [
      next(100, 1),
      error(200, TestError()),
      next(300, 3),
    ])
    test.assert(subject) { events in
      XCTAssertEqual(events, [
        next(100, 1),
        next(300, 3),
      ])
    }
  }

  func testIgnoreCompleted() {
    let test = RxExpect()
    let subject = ActionSubject<Int>()
    test.input(subject, [
      next(100, 1),
      completed(200),
      next(300, 3),
    ])
    test.assert(subject) { events in
      XCTAssertEqual(events, [
        next(100, 1),
        next(300, 3),
      ])
    }
  }
}
