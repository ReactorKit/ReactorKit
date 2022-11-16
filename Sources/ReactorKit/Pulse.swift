//
//  Pulse.swift
//  ReactorKit
//
//  Created by tokijh on 2021/01/11.
//

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

  public var projectedValue: Pulse<Value> {
    self
  }

  private mutating func riseValueUpdatedCount() {
    valueUpdatedCount &+= 1
  }
}
