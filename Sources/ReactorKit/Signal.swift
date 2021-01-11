//
//  Signal.swift
//  ReactorKit
//
//  Created by tokijh on 2021/01/11.
//

@propertyWrapper
public struct Signal<Value> {

  public var value: Value {
    didSet {
      self.riseValueUpdatedCount()
    }
  }
  var valueUpdatedCount = UInt.min

  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    get { return self.value }
    set { self.value = newValue }
  }

  public var projectedValue: Signal<Value> {
    return self
  }

  private mutating func riseValueUpdatedCount() {
    if self.valueUpdatedCount == UInt.max {
      self.valueUpdatedCount = UInt.min
    } else {
      self.valueUpdatedCount += 1
    }
  }
}

extension Signal: Equatable {
  public static func == (lhs: Signal<Value>, rhs: Signal<Value>) -> Bool {
    return lhs.valueUpdatedCount == rhs.valueUpdatedCount
  }
}
