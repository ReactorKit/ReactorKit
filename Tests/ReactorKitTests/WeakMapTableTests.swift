import XCTest
@testable import ReactorKit

final class WeakMapTableTests: XCTestCase {
  func testSetValueForKey() {
    let map = WeakMapTable<KeyObject, ValueObject>()

    let (key1, value1) = (KeyObject(), ValueObject())
    let (key2, value2) = (KeyObject(), ValueObject())
    map.setValue(value1, forKey: key1)
    map.setValue(value2, forKey: key2)

    XCTAssert(map.value(forKey: key1) === value1)
    XCTAssert(map.value(forKey: key2) === value2)
  }

  func testSetAnotherValue() {
    let map = WeakMapTable<KeyObject, ValueObject>()

    let key = KeyObject()
    weak var weakOldValue: ValueObject?
    weak var weakNewValue: ValueObject?

    _ = {
      let oldValue = ValueObject()
      map.setValue(oldValue, forKey: key)
      weakOldValue = oldValue

      let newValue = ValueObject()
      map.setValue(newValue, forKey: key)
      weakNewValue = newValue
    }()

    XCTAssertNil(weakOldValue)
    XCTAssertNotNil(weakNewValue)
    XCTAssert(map.value(forKey: key) === weakNewValue)
  }

  func testSetNil() {
    let map = WeakMapTable<KeyObject, ValueObject>()

    let key = KeyObject()
    weak var weakValue: ValueObject?

    _ = {
      let value = ValueObject()
      map.setValue(value, forKey: key)
      weakValue = value

      map.setValue(nil, forKey: key)
    }()

    XCTAssertNil(map.value(forKey: key))
    XCTAssertNil(weakValue)
  }

  func testDefaultValue() {
    let map = WeakMapTable<KeyObject, ValueObject>()

    let key = KeyObject()
    let expectedValue = ValueObject()
    let actualValue = map.value(forKey: key, default: expectedValue)

    XCTAssert(actualValue === expectedValue)
  }

  func testReleaseKeyAndValue() {
    let map = WeakMapTable<KeyObject, ValueObject>()

    weak var weakKey: KeyObject?
    weak var weakValue: ValueObject?

    _ = {
      let key = KeyObject()
      let value = ValueObject()
      map.setValue(value, forKey: key)
      weakKey = key
      weakValue = value
    }()

    XCTAssertNil(weakKey)
    XCTAssertNil(weakValue)
  }
}

private final class KeyObject {
}

private final class ValueObject {
}
