//
//  View.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 13/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

#if !os(Linux)
import Foundation

#if os(iOS) || os(tvOS)
import UIKit
private typealias OSViewController = UIViewController
#elseif os(OSX)
import AppKit
private typealias OSViewController = NSViewController
#endif

import RxSwift

public typealias _View = View

/// A View displays data. A view controller and a cell are treated as a view. The view binds user
/// inputs to the action stream and binds the view states to each UI component. There's no business
/// logic in a view layer. A view just defines how to map the action stream and the state stream.
public protocol View: class, AssociatedObjectStore {
  associatedtype Reactor: _Reactor

  /// A dispose bag. It is disposed each time the `reactor` is assigned.
  var disposeBag: DisposeBag { get set }

  /// A view's reactor. `bind(reactor:)` gets called when the new value is assigned to this property.
  var reactor: Reactor? { get set }

  /// Creates RxSwift bindings. This method is called each time the `reactor` is assigned.
  ///
  /// Here is a typical implementation example:
  ///
  /// ```
  /// func bind(reactor: MyReactor) {
  ///   // Action
  ///   increaseButton.rx.tap
  ///     .bind(to: Reactor.Action.increase)
  ///     .disposed(by: disposeBag)
  ///
  ///   // State
  ///   reactor.state.map { $0.count }
  ///     .bind(to: countLabel.rx.text)
  ///     .disposed(by: disposeBag)
  /// }
  /// ```
  ///
  /// - warning: It's not recommended to call this method directly.
  func bind(reactor: Reactor)
}


// MARK: - Associated Object Keys

private var reactorKey = "reactor"


// MARK: - Default Implementations

extension View {
  public var reactor: Reactor? {
    get { return self.associatedObject(forKey: &reactorKey) }
    set { self.setReactor(newValue) }
  }

  fileprivate func setReactor(_ reactor: Reactor?) {
    self.setAssociatedObject(reactor, forKey: &reactorKey)
    self.disposeBag = DisposeBag()
    if let reactor = reactor {
      self.performBinding(reactor: reactor)
    }
  }

  fileprivate func performBinding(reactor: Reactor) {
    guard self.reactor === reactor else { return }
    if self.shouldDeferBinding(reactor: reactor) {
      DispatchQueue.main.async { [weak self, weak reactor] in
        guard let `self` = self, let reactor = reactor else { return }
        self.performBinding(reactor: reactor)
      }
    } else {
      self.bind(reactor: reactor)
    }
  }

  fileprivate func shouldDeferBinding(reactor: Reactor) -> Bool {
    return (self as? OSViewController)?.isViewLoaded == false
  }
}
#endif
