# Implementing Reactor

We implemented `GitHubSearchViewReactor` with dummy data. In this chapter we'll use GitHub search API with URLSession. What we have to change is just a `mutate()` function implementation.

```swift
func mutate(action: Action) -> Observable<Mutation> {
  switch action {
  case let .updateQuery(query):
    if let query = query, !query.isEmpty {
      return URLSession.shared.rx.json(url: url)
        .map { json -> [String] in
          guard let dict = json as? [String: Any] else { return [] }
          guard let items = dict["items"] as? [[String: Any]] else { return [] }
          let repos = items.flatMap { $0["full_name"] as? String }
          return repos
        }
        .catchErrorJustReturn([])
        .map { Mutation.setRepos($0) }
    } else {
      return Observabe.just(Mutation.setRepos([])) // empty result
    }
  }
}
```

The reactor sends API requests each time the query changes. It's important to cancel previous request to prevent from unnecessary API requests. In general it's the responsibility of a `flatMapLatest()` but it is not available in the `mutate()`. In this case we can use `takeUntil()` with the action subject.

```swift
return URLSession.shared.rx.json(url: url)
  .map { json -> [String] in
    guard let dict = json as? [String: Any] else { return [] }
    guard let items = dict["items"] as? [[String: Any]] else { return [] }
    let repos = items.flatMap { $0["full_name"] as? String }
    return repos
  }
  .catchErrorJustReturn([])
  .map { Mutation.setRepos($0) }
  // dispose when the reactor emits next .updateQuery action
  .takeUntil(self.action.filter {
    if case .updateQuery = $0 {
      return true
    } else {
      return false
    }
  })
```

It's done!
