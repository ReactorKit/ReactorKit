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

public protocol _ObjcCompatibleView {
  func performBinding()
}

public typealias _View = View

/// A View displays data. A view controller and a cell are treated as a view. The view binds user
/// inputs to the action stream and binds the view states to each UI component. There's no business
/// logic in a view layer. A view just defines how to map the action stream and the state stream.
public protocol View: class, _ObjcCompatibleView, AssociatedObjectStore {
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
private var isReactorBindedKey = "isReactorBinded"


// MARK: - Default Implementations

extension View {
  public var reactor: Reactor? {
    get { return self.associatedObject(forKey: &reactorKey) }
    set { self.setReactor(newValue) }
  }

  fileprivate var isReactorBinded: Bool {
    get { return self.associatedObject(forKey: &isReactorBindedKey, default: false) }
    set { self.setAssociatedObject(newValue, forKey: &isReactorBindedKey) }
  }

  fileprivate func setReactor(_ reactor: Reactor?) {
    self.setAssociatedObject(reactor, forKey: &reactorKey)
    self.isReactorBinded = false
    self.disposeBag = DisposeBag()
    self.performBinding()
  }

  public func performBinding() {
    guard let reactor = self.reactor else { return }
    guard !self.isReactorBinded else { return }
    guard !self.shouldDeferBinding(reactor: reactor) else { return }
    self.bind(reactor: reactor)
    self.isReactorBinded = true
  }

  fileprivate func shouldDeferBinding(reactor: Reactor) -> Bool {
    #if !os(watchOS)
      return (self as? OSViewController)?.isViewLoaded == false
    #else
      return false
    #endif
  }
}

#if !os(watchOS)
extension OSViewController {
  @objc func _reactorkit_performBinding() {
    (self as? _ObjcCompatibleView)?.performBinding()
  }
}
#endif
#endif
