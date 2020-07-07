//
//  IdentityEquatable.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/07/06.
//

public protocol IdentityEquatable: class, Equatable {
}

public extension IdentityEquatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs === rhs
  }
}
