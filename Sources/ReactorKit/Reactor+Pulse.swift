//
//  Reactor+Pulse.swift
//  ReactorKit
//
//  Created by 윤중현 on 2021/03/31.
//

extension Reactor {
  /// Returns an observable sequence that emits the value of the pulse only when its valueUpdatedCount changes.
  ///
  /// - seealso: [Pulse document](https://github.com/ReactorKit/ReactorKit/blob/master/Documentation/Contents/Pulse.md)
  /// - seealso: [The official document introduction](https://github.com/ReactorKit/ReactorKit#pulse)
  ///
  /// - parameter transformToPulse: A transform function to apply to the current state of the reactor
  /// to produce a pulse.
  /// - returns: An observable that emits the value of the pulse whenever its valueUpdatedCount changes.
  public func pulse<Result>(_ transformToPulse: @escaping (State) throws -> Pulse<Result>) -> Observable<Result> {
    state.map(transformToPulse).distinctUntilChanged(\.valueUpdatedCount).map(\.value)
  }
}
