import XCTest
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
    // given
    let subject = ActionSubject<Int>()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    scheduler
      .createHotObservable([
        .next(100, 1),
        .next(200, 2),
        .next(300, 3),
      ])
      .subscribe(subject)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { subject.asObservable() }
    XCTAssertEqual(response.events, [
      .next(100, 1),
      .next(200, 2),
      .next(300, 3),
    ])
  }

  func testIgnoreError() {
    // given
    let subject = ActionSubject<Int>()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    scheduler
      .createHotObservable([
        .next(100, 1),
        .error(200, TestError()),
        .next(300, 3),
      ])
      .subscribe(subject)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { subject.asObservable() }
    XCTAssertEqual(response.events, [
      .next(100, 1),
      .next(300, 3),
    ])
  }

  func testIgnoreCompleted() {
    // given
    let subject = ActionSubject<Int>()
    let scheduler = TestScheduler(initialClock: 0)
    let disposeBag = DisposeBag()

    // when
    scheduler
      .createHotObservable([
        .next(100, 1),
        .completed(200),
        .next(300, 3),
      ])
      .subscribe(subject)
      .disposed(by: disposeBag)

    // then
    let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) { subject.asObservable() }
    XCTAssertEqual(response.events, [
      .next(100, 1),
      .next(300, 3),
    ])
  }
}
