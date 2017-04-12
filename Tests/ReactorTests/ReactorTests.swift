import XCTest
@testable import ReactorKit

class ReactorKitTests: XCTestCase {
  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCTAssertEqual(ReactorKit().text, "Hello, World!")
  }


  static var allTests = [
    ("testExample", testExample),
  ]
}
