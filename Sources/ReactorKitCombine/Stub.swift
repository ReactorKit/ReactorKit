//
//  Stub.swift
//  ReactorKitCombine
//
//  Created by tokijh on 2020/06/29.
//

import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class Stub<Reactor: ReactorKitCombine.Reactor> {
  private unowned var reactor: Reactor
  private var cancellables: Set<AnyCancellable>

  public let state: StateRelay<Reactor.State>
  public let action: ActionSubject<Reactor.Action>
  public private(set) var actions: [Reactor.Action] = []

  public init(reactor: Reactor, cancellables: Set<AnyCancellable>) {
    self.reactor = reactor
    self.cancellables = cancellables
    self.state = .init(reactor.initialState)
    self.state
      .sink(receiveValue: { [weak reactor] state in
        reactor?.currentState = state
      })
      .store(in: &self.cancellables)
    self.action = .init()
    self.action
      .sink(receiveValue: { [weak self] action in
        self?.actions.append(action)
      })
      .store(in: &self.cancellables)
  }
}
