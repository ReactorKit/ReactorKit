//
//  Rx+Signal.swift
//  ReactorKit
//
//  Created by 윤중현 on 2021/01/11.
//

import RxSwift

extension ObservableType {
  public func distinctAndMapToValue<Value>() -> Observable<Value> where Element == Signal<Value> {
    return self.distinctUntilChanged().map(\.value)
  }

  public func distinctAndCompactMapToValue<Value>() -> Observable<Value> where Element == Signal<Value?> {
    return self.distinctAndMapToValue().compactMap { $0 }
  }
}
