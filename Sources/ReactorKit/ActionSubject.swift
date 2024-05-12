//
//  ActionSubject.swift
//  ReactorKit
//
//  Created by Suyeol Jeon on 14/05/2017.
//
//

import class Foundation.NSLock.NSRecursiveLock

import RxSwift

/// A special subject for Reactor's Action. It only emits `.next` event. it can't terminate with error or completed.
public final class ActionSubject<Element>: SubjectType, ObserverType {

  private let lock = NSRecursiveLock()
  private let subject: PublishSubject<Element>

  /// Initializes with internal empty subject.
  public init() {
    subject = PublishSubject()
  }

  /// Subscribes observer
  public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
    subject.subscribe(observer)
  }

  /// emits it to subscribers
  public func onNext(_ element: Element) {
    subject.on(.next(element))
  }

  /// Synchronized OnNext
  public func on(_ event: Event<Element>) {
    self.lock.lock(); defer { self.lock.unlock() }
    if case let .next(element) = event {
      subject.onNext(element)
    }
  }
}
