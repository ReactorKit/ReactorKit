//
//  IdentityEquatable.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 2019/10/17.
//

public protocol IdentityEquatable: AnyObject, Equatable {
}

public extension IdentityEquatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs === rhs
  }
}
