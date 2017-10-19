import RxSwift

#if !os(Linux)
#if os(iOS) || os(tvOS)
import UIKit
private typealias OSViewController = UIViewController
#elseif os(OSX)
import AppKit
private typealias OSViewController = NSViewController
#endif

public protocol _ObjCStoryboardView {
  func performBinding()
}

public protocol StoryboardView: View, _ObjCStoryboardView {
}

extension StoryboardView {
  public var reactor: Reactor? {
    get { return self.associatedObject(forKey: &reactorKey) }
    set {
      self.setAssociatedObject(newValue, forKey: &reactorKey)
      self.isReactorBinded = false
      self.disposeBag = DisposeBag()
      self.performBinding()
    }
  }

  fileprivate var isReactorBinded: Bool {
    get { return self.associatedObject(forKey: &isReactorBindedKey, default: false) }
    set { self.setAssociatedObject(newValue, forKey: &isReactorBindedKey) }
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
    (self as? _ObjCStoryboardView)?.performBinding()
  }
}
#endif
#endif
