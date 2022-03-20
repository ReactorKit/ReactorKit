//
//  Distinct.swift
//  ReactorKit
//
//  Created by Haeseok Lee on 2022/03/20.
//

import Foundation

@propertyWrapper
public struct Distinct<Value: Hashable> {
  
  private let id: UUID = UUID()
  
  public var value: Value
  
  public var storedHashValue: Int? {
    HashableStateCacheManager.lookUp(key: id)
  }
  
  public var isDirty: Bool {
    get {
      let newHashValue = self.value.hashValue
      let oldHashValue = self.storedHashValue
      if newHashValue != oldHashValue {
        HashableStateCacheManager.store(key: self.id, value: newHashValue)
        return true
      }
      return false
    }
  }
  
  public var wrappedValue: Value {
    get { self.value }
    set { self.value = newValue }
  }
  
  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }
  
  public var projectedValue: Distinct<Value> {
    return self
  }
}

fileprivate struct HashableStateCacheManager {
  
  private typealias HashID = NSNumber
  private typealias HashValue = NSNumber
  private static let shared: NSCache<HashID, HashValue> = NSCache<HashID, HashValue>()
  
  static func lookUp(key: UUID) -> Int? {
    let key = NSNumber(value: key.hashValue)
    if let hashValue = HashableStateCacheManager.shared.object(forKey: key) {
      return hashValue as? Int
    }
    return nil
  }
  
  static func store(key: UUID, value: Int) {
    let (key, value) = (NSNumber(value: key.hashValue), NSNumber(value: value))
    shared.setObject(value, forKey: key)
  }
}
