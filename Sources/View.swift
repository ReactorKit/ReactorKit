//
//  View.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 13/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

#if !os(Linux)
import Foundation

import RxSwift

public typealias _View = View
public protocol View: class, AssociatedObjectStore {
  associatedtype Reactor: _Reactor

  var disposeBag: DisposeBag { get set }
  var reactor: Reactor? { get set }

  /// Binds View with Reactor.
  ///
  /// - warning: Don't call this method directly.
  func bind(reactor: Reactor)
}



// MARK: - Default Implementations

extension View {
  public var reactor: Reactor? {
    get { return self.associatedObject(forKey: .reactor) }
    set {
      guard self.reactor !== newValue else { return }
      self.setAssociatedObject(newValue, forKey: .reactor)
      self.disposeBag = DisposeBag()
      if let reactor = newValue {
        self.bind(reactor: reactor)
      }
    }
  }
}
#endif
