//
//  IdentityEquatable.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 2019/10/17.
//

public protocol IdentityEquatable: AnyObject, Equatable {}

extension IdentityEquatable {
  @inlinable
  @inline(__always)
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs === rhs
  }
}
