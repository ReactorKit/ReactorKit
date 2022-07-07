//
//  Reactor+Pulse.swift
//  ReactorKit
//
//  Created by 윤중현 on 2021/03/31.
//

extension Reactor {
  public func pulse<Result>(_ transformToPulse: @escaping (State) throws -> Pulse<Result>) -> Observable<Result> {
    return self.state.map(transformToPulse).distinctUntilChanged(\.valueUpdatedCount).map(\.value)
  }
  public func pulseNil<Result>(_ transformToPulse: @escaping (State) throws -> Pulse<Result?>) -> Observable<Result> {
    let pulse = self.state.map(transformToPulse).distinctUntilChanged(\.valueUpdatedCount).map(\.value)
    return pulse.compactMap { $0 }
  }
}
