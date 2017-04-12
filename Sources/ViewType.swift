//
//  ViewType.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 13/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

#if !os(Linux)
import Foundation

import RxSwift

private struct AssociatedObjectKey {
  static let reactor = "reactor"
}

public protocol ViewType: class {
  associatedtype Reactor: ReactorType

  var disposeBag: DisposeBag { get set }
  var reactor: Reactor? { get set }

  /// Configure View using Reactor. Don't call this method directly.
  func configure(reactor: Reactor)
}

extension ViewType {
  public var reactor: Reactor? {
    get {
      let key = AssociatedObjectKey.reactor
      return objc_getAssociatedObject(self, key) as? Reactor
    }
    set {
      let key = AssociatedObjectKey.reactor
      objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      if self.reactor !== newValue {
        self.disposeBag = DisposeBag()
      }
      if let reactor = newValue {
        self.configure(reactor: reactor)
      }
    }
  }
}
#endif
