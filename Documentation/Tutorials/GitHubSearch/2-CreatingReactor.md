# Creating Reactor

## Empty Reactor

If you have finished building an user interface, it's time to create a first reactor. Reactor is an UI independent layer which manages the state of a view.

Create a new swift file named **`GitHubSearchViewReactor.swift`** and define a empty reactor.

**GitHubSearchViewReactor.swift**

```swift
import ReactorKit

final class GitHubSearchViewReactor: Reactor {
  enum Action {
  }

  enum Mutation {
  }

  struct State {
  }

  let initialState = State()
}
```

## Action, Mutation and State

You'll find that `GitHubSearchViewReactor` conforms to the protocol `Reactor`. This protocol requires three types: `Action`, `Mutation` and `State`. Action represents an user input such as refresh or search. State defines a view state such as search results. Mutation is an operation that manipulates the state.

GitHubSearch will call search API each time user changes the query text. This user interaction can be represented as an action: `updateQuery(String?)`.

```swift
enum Action {
  // user changes the query text
  case updateQuery(String?)
}
```

Let's assume that the search result is an array of repository names. The table view needs this value to draw user interface so we can call this a view state. Let's add a property to a struct `State`.

```swift
struct State {
  // search result (array of repository names)
  var repos: [String]
}
```

The state can only be changed via `Mutation`. In general mutations correspond to each property of the state. In this case we have a single property so we can define a single mutation as `setRepos([String])`.

```swift
enum Mutation {
  // update State.repos
  case setRepos([String])
}
```

## Reactor Flow

When a user changes the text in the search bar, `Action.updateQuery` will be sent to the reactor. Then the reactor will convert the action to the `Mutation.setRepos` asynchronously. Then the mutation will change the current state and this state will be sent back to the view. Here is the complete flow of a reactor:

![flow](https://cloud.githubusercontent.com/assets/931655/25098066/2de21a28-23e2-11e7-8a41-d33d199dd951.png)

## Implementing `mutate()` and `reduce()`

There are two functions between each steps: Action-Mutation and Mutation-State. `mutate()` function converts an action to a mutation and `reduce()` function generates a new state from a mutation. Here are the function definitions:

```swift
// converts Action to Mutation
func mutate(action: Action) -> Observable<Mutation>

// generates a new State from an old State and a Mutation
func reduce(state: State, mutation: Mutation) -> State
```

We'll implement `mutate()` with dummy data first. This function gets called each time the reactor receives actions. The code below filters the action with `switch-case` statement and returns a `Mutation.setRepos` with dummy data.

```swift
func mutate(action: Action) -> Observable<Mutation> {
  switch action {
  case let .updateQuery(query): // when user updates the search query
    if let query = query {
      let dummyRepos = ["\(query)1", "\(query)2", "\(query)3"] // dummy result
      return Observable.just(Mutation.setRepos(dummyRepos))
    } else {
      return Observable.just(Mutation.setRepos([])) // empty result
    }
  }
}
```

`reduce()` function gets called each time the reactor emits mutations from `mutate()`. The code below filters the mutation with `switch-case` and returns a new state.

```swift
func reduce(state: State, mutation: Mutation) -> State {
  switch mutation {
  case let .setRepos(repos):
    return State(repos: repos) // returns a new state
  }
}
```

And this is the complete code:

**GitHubSearchViewReactor.swift**

```swift
import ReactorKit

final class GitHubSearchViewReactor: Reactor {
  enum Action {
    // user changes the query text
    case updateQuery(String?)
  }

  enum Mutation {
    // update State.repos
    case setRepos([String])
  }

  struct State {
    // search result (array of repository names)
    var repos: [String]
  }

  let initialState = State(repos: [])

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .updateQuery(query): // when user updates the search query
      if let query = query {
        let dummyRepos = ["\(query)1", "\(query)2", "\(query)3"] // dummy result
        return Observable.just(Mutation.setRepos(dummyRepos))
      } else {
        return Observable.just(Mutation.setRepos([])) // empty result
      }
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    switch mutation {
    case let .setRepos(repos):
      return State(repos: repos) // returns a new state
    }
  }
}
```
