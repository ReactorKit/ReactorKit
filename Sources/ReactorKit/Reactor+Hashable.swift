//
//  Reactor+Hashable.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 2019/10/17.
//

public extension Reactor where Self: Hashable, State: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.currentState.hashValue)
  }
}
