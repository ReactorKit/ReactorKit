//
//  Reactor+Distinct.swift
//  ReactorKit
//
//  Created by Haeseok Lee on 2022/03/20.
//

import Foundation

extension Reactor {
  public func state<Result: Hashable>(_ transformToDistinct: @escaping (State) throws -> Distinct<Result>) -> Observable<Result> {
    return self.state.map(transformToDistinct).filter(\.isDirty).map(\.value)
  }
}
