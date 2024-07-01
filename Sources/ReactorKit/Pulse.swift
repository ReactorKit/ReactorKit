//
//  Pulse.swift
//  ReactorKit
//
//  Created by tokijh on 2021/01/11.
//

/// A property wrapper type that allows to receive events only if the new value is assigned, even if it is the same value.
///
/// If you want to see examples, see [Pulse](https://github.com/ReactorKit/ReactorKit?tab=readme-ov-file#pulse).
@propertyWrapper
public struct Pulse<Value> {

  public var value: Value {
    didSet {
      riseValueUpdatedCount()
    }
  }

  public internal(set) var valueUpdatedCount = UInt.min

  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    get { value }
    set { value = newValue }
  }

  public var projectedValue: Self {
    self
  }

  private mutating func riseValueUpdatedCount() {
    valueUpdatedCount &+= 1
  }
}
