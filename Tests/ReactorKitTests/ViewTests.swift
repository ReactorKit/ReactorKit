import XCTest
import ReactorKit
import RxSwift

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

  func testViewControllerIsViewLoaded() {
    let viewController = TestViewController()
    XCTAssertEqual(viewController.isViewLoaded, false)
    viewController.reactor = TestReactor()
    XCTAssertEqual(viewController.isViewLoaded, true)
    XCTAssertEqual(viewController.bindInvokeCount, 1)
  }
}

private final class TestView: View {
  var disposeBag = DisposeBag()
  var bindInvokeCount = 0

  func bind(reactor: TestReactor) {
    self.bindInvokeCount += 1
  }
}

private final class TestViewController: OSViewController, View {
  var disposeBag = DisposeBag()
  var bindInvokeCount = 0

  override func loadView() {
    self.view = OSView()
  }

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
