//
//  GitHubSearchViewReactor.swift
//  GitHubSearch
//
//  Created by Suyeol Jeon on 13/05/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import ReactorKit
import RxSwift

final class GitHubSearchViewReactor: Reactor {
  enum Action {
    case updateQuery(String?)
  }

  enum Mutation {
    case setRepos([String])
  }

  struct State {
    var repos: [String] = []
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .updateQuery(query):
      if let query = query {
        let dummyRepos = ["\(query)1", "\(query)2", "\(query)3"]
        return Observable.just(Mutation.setRepos(dummyRepos))
      } else {
        return Observable.just(Mutation.setRepos([]))
      }
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    switch mutation {
    case let .setRepos(repos):
      var newState = state
      newState.repos = repos
      return newState
    }
  }
}
