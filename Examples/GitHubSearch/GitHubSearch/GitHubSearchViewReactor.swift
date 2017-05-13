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
    case setQuery(String?)
    case setRepos([String])
  }

  struct State {
    var query: String?
    var repos: [String] = []
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .updateQuery(query):
      return Observable.concat([
        // 1) set current state's query (.setQuery)
        Observable.just(Mutation.setQuery(query)),

        // 2) call API and set repos (.setRepos)
        self.search(query: query)
          // cancel previous request when the new `.updateQuery` action is fired
          .takeUntil(self.action.filter(isUpdateQueryAction))
          .map { Mutation.setRepos($0) },
      ])
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    switch mutation {
    case let .setQuery(query):
      var newState = state
      newState.query = query
      return newState

    case let .setRepos(repos):
      var newState = state
      newState.repos = repos
      return newState
    }
  }

  private func url(for query: String?) -> URL? {
    guard let query = query, !query.isEmpty else { return nil }
    return URL(string: "https://api.github.com/search/repositories?q=\(query)")
  }

  private func search(query: String?) -> Observable<[String]> {
    guard let url = self.url(for: query) else { return .just([]) }
    return URLSession.shared.rx.json(url: url)
      .map { json -> [String] in
        guard let dict = json as? [String: Any] else { return [] }
        guard let items = dict["items"] as? [[String: Any]] else { return [] }
        return items.flatMap { $0["full_name"] as? String }
      }
  }

  private func isUpdateQueryAction(_ action: Action) -> Bool {
    if case .updateQuery = action {
      return true
    } else {
      return false
    }
  }

}
