import XCTest
@testable import Reactor

class ReactorTests: XCTestCase {
  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCTAssertEqual(Reactor().text, "Hello, World!")
  }


  static var allTests = [
    ("testExample", testExample),
  ]
}
