//
//  IdentityHashable.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/07/06.
//

public protocol IdentityHashable: Hashable, IdentityEquatable {
}

public extension IdentityHashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self).hashValue)
  }
}
