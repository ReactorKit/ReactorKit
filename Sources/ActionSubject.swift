//
//  ActionSubject.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 14/05/2017.
//
//

import class Foundation.NSLock.NSRecursiveLock

import RxSwift

/// A special subject for Reactor's Action. It only emits `.next` event.
public final class ActionSubject<Element>: ObservableType, ObserverType, SubjectType {
  public typealias E = Element
  typealias Key = UInt

  var lock = NSRecursiveLock()

  var nextKey: Key = 0
  var observers: [Key: (Event<Element>) -> ()] = [:]

  #if TRACE_RESOURCES
  init() {
    _ = Resources.incrementTotal()
  }
  #endif

  #if TRACE_RESOURCES
  deinit {
    _ = Resources.decrementTotal()
  }
  #endif

  public func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.E == Element {
    self.lock.lock()
    let key = self.nextKey
    self.nextKey += 1
    self.observers[key] = observer.on
    self.lock.unlock()

    return Disposables.create { [weak self] in
      self?.lock.lock()
      self?.observers.removeValue(forKey: key)
      self?.lock.unlock()
    }
  }

  public func on(_ event: Event<Element>) {
    self.lock.lock()
    if case .next = event {
      self.observers.values.forEach { $0(event) }
    }
    self.lock.unlock()
  }
}
