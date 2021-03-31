//
//  Reactor+Signal.swift
//  ReactorKit
//
//  Created by 윤중현 on 2021/03/31.
//

extension Reactor {
  public func signal<Result>(_ transformToSignal: @escaping (State) throws -> Signal<Result>) -> Observable<Result> {
    return self.state.map(transformToSignal).distinctUntilChanged().map(\.value)
  }
}
