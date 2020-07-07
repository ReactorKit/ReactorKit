//
//  Replay.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//

import Combine

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension Publisher {
  func replay(_ bufferSize: Int) -> Publishers.Multicast<Self, ReplaySubject<Output, Failure>> {
    return self.multicast(subject: ReplaySubject(bufferSize: bufferSize))
  }
}
