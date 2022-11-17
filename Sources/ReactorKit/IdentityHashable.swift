//
//  IdentityHashable.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 2019/10/17.
//

public protocol IdentityHashable: Hashable, IdentityEquatable {}

extension IdentityHashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self).hashValue)
  }
}
