import XCTest
import ReactorKit
import RxSwift

#if !os(Linux)
final class ViewTests: XCTestCase {
  func testBindIsInvoked_differentReactor() {
    let view = TestView()
    XCTAssertEqual(view.bindInvokeCount, 0)
    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 1)
    view.reactor = TestReactor()
    XCTAssertEqual(view.bindInvokeCount, 2)
  }

  func testDisposeBagIsDisposed_differentReactor() {
    let view = TestView()
    let oldHashValue = ObjectIdentifier(view.disposeBag).hashValue
    view.reactor = TestReactor()
    let newHashValue = ObjectIdentifier(view.disposeBag).hashValue
    XCTAssertNotEqual(oldHashValue, newHashValue)
  }

  func testReactor_assign() {
    let reactor = TestReactor()
    let view = TestView()
    view.reactor = reactor
    XCTAssertNotNil(view.reactor)
    XCTAssertTrue(view.reactor === reactor)
  }

  func testReactor_assignNil() {
    let reactor = TestReactor()
    let view = TestView()
    view.reactor = reactor
    view.reactor = nil
    XCTAssertNil(view.reactor)
  }

  func testStoryboardView_performBinding() {
    let reactor = TestReactor()
    let view = TestStoryboardView()
    view.reactor = reactor
    XCTAssertEqual(view.bindInvokeCount, 0)
    view.bindReactor()
    XCTAssertEqual(view.bindInvokeCount, 1)
    view.reactor = reactor
    XCTAssertEqual(view.bindInvokeCount, 1)
    view.bindReactor()
    XCTAssertEqual(view.bindInvokeCount, 2)
  }
}

private final class TestView: View {
  var disposeBag = DisposeBag()
  var bindInvokeCount = 0

  func bind(reactor: TestReactor) {
    self.bindInvokeCount += 1
  }
}

private final class TestStoryboardView: StoryboardView {
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
#endif
