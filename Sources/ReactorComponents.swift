//
//  ReactorComponents.swift
//  Reactor
//
//  Created by Suyeol Jeon on 13/04/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

public protocol ReactorComponents {
  associatedtype Action
  associatedtype Mutation
  associatedtype State
}

public struct NoAction {}
public struct NoMutation {}
