//
//  Reacctor+Equatable.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 2019/10/17.
//

public extension Reactor where Self: Equatable, State: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.currentState == rhs.currentState
  }
}
