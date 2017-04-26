import XCTest
@testable import ReactorKit

final class AssociatedObjectStoreTests: XCTestCase {
  func testAssociatedObject() {
    let store = Store()
    let object = Object()
    var key = "object"
    store.setAssociatedObject(object, forKey: &key)
    let poppedObject: Object = store.associatedObject(forKey: &key)!
    XCTAssertEqual(ObjectIdentifier(object).hashValue, ObjectIdentifier(poppedObject).hashValue)
  }

  func testDealloc() {
    var isStoreDeallocated = false
    var isObjectDeallocated = false
    func scope() {
      let store = Store()
      store.deinitClosure = { isStoreDeallocated = true }
      let object = Object()
      object.deinitClosure = { isObjectDeallocated = true }
      var key = "object"
      store.setAssociatedObject(object, forKey: &key)
    }
    scope()
    XCTAssertTrue(isStoreDeallocated)
    XCTAssertTrue(isObjectDeallocated)
  }
}

private final class Store: AssociatedObjectStore {
  var deinitClosure: (() -> Void)?
  deinit {
    self.deinitClosure?()
  }
}

private final class Object: AssociatedObjectStore {
  var deinitClosure: (() -> Void)?
  deinit {
    self.deinitClosure?()
  }
}
