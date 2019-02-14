//
//  StateRelay.swift
//  ReactorKit
//
//  Created by tokijh on 05/10/2018.
//

import RxSwift

/// StateRelay is a wrapper for `BehaviorSubject`.
///
/// Unlike `BehaviorSubject` it can't terminate with error or completed.
public final class StateRelay<Element>: ObservableType {
    public typealias E = Element
    
    private let _subject: BehaviorSubject<Element>
    
    /// Accepts `event` and emits it to subscribers
    public func accept(_ event: Element) {
        _subject.onNext(event)
    }
    
    /// Gets or sets current value of behavior subject
    ///
    /// Whenever a new value is set, all the observers are notified of the change.
    ///
    /// Even if the newly set value is same as the old value, observers are still notified for change.
    public var value: Element {
        get {
            // this try! is ok because subject can't error out or be disposed
            return try! _subject.value()
        }
        set(newValue) {
            accept(newValue)
        }
    }
    
    /// Initializes behavior relay with initial value.
    public init(value: Element) {
        _subject = BehaviorSubject(value: value)
    }
    
    /// Subscribes observer
    public func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.E == E {
        return _subject.subscribe(observer)
    }
    
    /// - returns: Canonical interface for push style sequence
    public func asObservable() -> Observable<Element> {
        return _subject.asObservable()
    }
}
