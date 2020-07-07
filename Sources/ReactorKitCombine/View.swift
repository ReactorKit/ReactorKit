//
//  View.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/07/06.
//

#if !os(Linux)
import Combine
import WeakMapTable

private typealias AnyView = AnyObject
private enum MapTables {
  static let reactor = WeakMapTable<AnyView, Any>()
}

/// A View displays data. A view controller and a cell are treated as a view. The view binds user
/// inputs to the action stream and binds the view states to each UI component. There's no business
/// logic in a view layer. A view just defines how to map the action stream and the state stream.
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol View: class {
  associatedtype Reactor: ReactorKitCombine.Reactor

  /// A dispose bag. It is disposed each time the `reactor` is assigned.
  var cancellables: Set<AnyCancellable> { get set }

  /// A view's reactor. `bind(reactor:)` gets called when the new value is assigned to this property.
  var reactor: Reactor? { get set }

  /// Creates Combine bindings. This method is called each time the `reactor` is assigned.
  ///
  /// Here is a typical implementation example:
  ///
  /// ```
  /// func bind(reactor: MyReactor) {
  ///   // Action
  ///   increaseButton.rx.tap
  ///     .assign(to: Reactor.Action.increase)
  ///     .disposed(by: disposeBag)
  ///
  ///   // State
  ///   reactor.state.map { $0.count }
  ///     .assign(to: countLabel.rx.text)
  ///     .disposed(by: disposeBag)
  /// }
  /// ```
  ///
  /// - warning: It's not recommended to call this method directly.
  func bind(reactor: Reactor)
}

// MARK: - Default Implementations

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension View {
  public var reactor: Reactor? {
    get { return MapTables.reactor.value(forKey: self) as? Reactor }
    set {
      MapTables.reactor.setValue(newValue, forKey: self)
      self.cancellables = []
      if let reactor = newValue {
        self.bind(reactor: reactor)
      }
    }
  }
}
#endif
