import RxSwift

#if !os(Linux)
#if os(iOS) || os(tvOS)
import UIKit
private typealias OSViewController = UIViewController
#elseif os(macOS)
import AppKit
private typealias OSViewController = NSViewController
#endif

import WeakMapTable

private typealias AnyView = AnyObject
private enum MapTables {
  static let reactor = WeakMapTable<AnyView, Any>()
  static let isReactorBinded = WeakMapTable<AnyView, Bool>()
}

@MainActor
public protocol _ObjCStoryboardView {
  func performBinding()
}

public protocol StoryboardView: View, _ObjCStoryboardView {}

@MainActor
extension StoryboardView {
  public var reactor: Reactor? {
    get { MapTables.reactor.value(forKey: self) as? Reactor }
    set {
      MapTables.reactor.setValue(newValue, forKey: self)
      isReactorBinded = false
      disposeBag = DisposeBag()
      performBinding()
    }
  }

  fileprivate var isReactorBinded: Bool {
    get { MapTables.isReactorBinded.value(forKey: self, default: false) }
    set { MapTables.isReactorBinded.setValue(newValue, forKey: self) }
  }

  public func performBinding() {
    guard let reactor = reactor else { return }
    guard !isReactorBinded else { return }
    guard !shouldDeferBinding(reactor: reactor) else { return }
    bind(reactor: reactor)
    isReactorBinded = true
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
  @objc
  func _reactorkit_performBinding() {
    (self as? _ObjCStoryboardView)?.performBinding()
  }
}
#endif
#endif
