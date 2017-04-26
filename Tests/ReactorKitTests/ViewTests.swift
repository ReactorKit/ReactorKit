import XCTest
import ReactorKit
import RxSwift

final class ViewTests: XCTestCase {
  func testBindIsInvoked_differentReactor() {
    let view = TestView()
    XCTAssertEqual(view.bindInvokeCount, 0)
    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 1)
    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 2)
  }

  func testBindIsInvoked_sameReactor() {
    let reactor = TestReactor()
    let view = TestView()
    XCTAssertEqual(view.bindInvokeCount, 0)
    view.reactor = reactor
    XCTAssertEqual(view.bindInvokeCount, 1)
    view.reactor = reactor // same reactor
    XCTAssertEqual(view.bindInvokeCount, 1)
  }

  func testDisposeBagIsDisposed_differentReactor() {
    let view = TestView()
    let oldHashValue = ObjectIdentifier(view.disposeBag).hashValue
    view.reactor = TestReactor()
    let newHashValue = ObjectIdentifier(view.disposeBag).hashValue
    XCTAssertNotEqual(oldHashValue, newHashValue)
  }

  func testDisposeBagIsNotDisposed_sameReactor() {
    let reactor = TestReactor()
    let view = TestView()
    view.reactor = reactor
    let oldHashValue = ObjectIdentifier(view.disposeBag).hashValue
    view.reactor = reactor // same reactor
    let newHashValue = ObjectIdentifier(view.disposeBag).hashValue
    XCTAssertEqual(oldHashValue, newHashValue)
  }
}

private final class TestView: View {
  var disposeBag = DisposeBag()
  var bindInvokeCount = 0

  func bind(reactor: TestReactor) {
    self.bindInvokeCount += 1
  }
}

private final class TestReactor: Reactor {
  typealias Action = NoAction
  struct State {}
  let initialState = State()
}
