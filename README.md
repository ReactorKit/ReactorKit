# ReactorKit

ReactorKit is a framework for reactive and unidirectional Swift application architecture. This repository introduces the basic concept of ReactorKit and describes how to build an application using ReactorKit.

You may want to see [Examples](#examples) section first if you'd like to see the actual code.

---

## ⚠️ Prereleasing Stage

ReactorKit is currently in prereleasing stage. Everything can be changed in the future. Major changes can be found in the [Changelog](#changelog) section.

---

## Table of Contents

* [Basic Concept](#basic-concept)
    * [View](#view)
    * [Reactor](#reactor)
* [Advanced](#advanced)
    * [Service](#service)
    * [ServiceProvider](#serviceprovider)
* [Conventions](#conventions)
* [Examples](#examples)
* [Dependencies](#dependencies)
* [Requirements](#requirements)
* [Installation](#installation)
* [Contributing](#contribution)
* [Changelog](#changelog)
* [License](#license)

## Basic Concept

ReactorKit is a combination of [Flux](https://facebook.github.io/flux/) and [Reactive Programming](https://en.wikipedia.org/wiki/Reactive_programming). The user actions and the view states are delivered to each layer via observable streams. These streams are unidirectional so the view can only emit actions and the reactor can only emit states.

<p align="center">
  <img alt="flow" src="https://cloud.githubusercontent.com/assets/931655/25073432/a91c1688-2321-11e7-8f04-bf91031a09dd.png" width="600">
</p>

### View

*View* displays data. A view controller and a cell are treated as a view. The view binds user-inputs to the action stream and binds the view states to each UI components. There's no business logic in a view layer. A view just defines how to map the action stream and the state stream.

To define a view, just conform a protocol named `View` to an existing class. Then your class will have a property named `reactor` automatically. This property is typically set outside of the view.

```swift
class ProfileViewController: UIViewController, View {
  var disposeBag = DisposeBag()
}

profileViewController.reactor = UserViewReactor() // inject reactor
```

When the `reactor` property has changed, `bind(reactor:)` gets called. Implement this method to define the bindings of an action stream and a state stream.

```swift
func bind(reactor: ProfileViewReactor) {
  // action (View -> Reactor)
  refreshButton.rx.tap.map { Reactor.Action.refresh }
    .bindTo(reactor.action)
    .addDisposableTo(self.disposeBag)

  // state (Reactor -> View)
  reactor.state.map { $0.isFollowing }
    .bindTo(followButton.rx.isSelected)
    .addDisposableTo(self.disposeBag)
}
```

### Reactor

*Reactor* is an UI independent layer which manages the state of a view. The foremost role of a reactor is to separate control flow from a view. Every view has its corresponding reactor and delegates every logical things to its reactor. A reactor has no dependency of a view so it can be easily tested.

Conform a protocol named `Reactor` to define a reactor. This protocol requires three types: `Action`, `Mutation` and `State`. It also requies a property named `initialState`.

```swift
class ProfileViewReactor: Reactor {
  // about what user did
  enum Action {
    case refreshFollowingStatus(Int)
    case follow(Int)
  }

  // about how to manipulate the state
  enum Mutation {
    case setFollowing(Bool)
  }

  // about current view state
  struct State {
    var isFollowing: Bool = false
  }

  let initialState: State = State()
}
```

`Action` represents an user interaction and `State` represents a view state. `Mutation` is a bridge between `Action` and `State`. A reactor converts the action stream to the state stream in two steps: `mutate()` and `reduce()`.

<p align="center">
  <img alt="flow-reactor" src="https://cloud.githubusercontent.com/assets/931655/25098066/2de21a28-23e2-11e7-8a41-d33d199dd951.png" width="800">
</p>

#### `mutate()`

`mutate()` receives an `Action` and generates an `Observable<Mutation>`.

```swift
func mutate(action: Action) -> Observable<Mutation>
```

Every side effect such as async operation or API call are performed in this method.

```swift
func mutate(action: Action) -> Observable<Mutation> {
  switch action {
  case let .refreshFollowingStatus(userID): // receive an action
    return UserAPI.isFollowing(userID) // create an API stream
      .map { (isFollowing: Bool) -> Mutation in
        return Mutation.setFollowing(isFollowing) // convert to Mutation stream
      }

  case let .follow(userID):
    return UserAPI.follow()
      .map { _ -> Mutation in
        return Mutation.setFollowing(true)
      }
  }
}
```

#### `reduce()`

`reduce()` generates a new `State` from an old `State` and a `Mutation`. 

```swift
func reduce(state: State, mutation: Mutation) -> State
```

This method is a pure function. It should just return a new `State` synchronously. Don't perform any side effects in this function.

```swift
func reduce(state: State, mutation: Mutation) -> State {
  var state = state // create a copy of old state
  switch mutation {
  case let .setFollowing(isFollowing):
    state.isFollowing = isFollowing // manipulate a new state
    return state // return a new state
  }
}
```

## Advanced

### Service

ReactorKit has a special layer named *Service*. A service layer does an actual business logic. A reactor is a middle layer between a view and a service which manages event streams. When a reactor receives an user action from a view, the reactor calls the service logic. The service makes a network request and sends the response back to the reactor. Then the reactor create a mutation stream with the service response.

Use this snippet for base service class:

```swift
class Service {
  unowned let provider: ServiceProviderType

  init(provider: ServiceProviderType) {
    self.provider = provider
  }
}
```

Here is an example of service:

```swift
protocol UserServiceType {
  func user(id: Int) -> Observable<User>
  func follow(id: Int) -> Observable<Void>
}

final class UserService: UserServiceType, Service {
  func user(id: Int) -> Observable<User> {
    return foo()
  }
  
  func follow(id: Int) -> Observable<Void> {
    return bar()
  }
}
```

### ServiceProvider

A single reactor can communicate with many services. *ServiceProvider* provides the references of each services to the reactor. The service provider is created once in the whole application life cycle and passed to the first reactor. The first reactor should pass the same reference of the service provider instance to a child reactor.

This is an example service provider:

```swift
protocol ServiceProviderType: class {
  var userDefaultsService: UserDefaultsServiceType { get }
  var userService: UserServiceType { get }
}

final class ServiceProvider: ServiceProviderType {
  lazy var userDefaultsService: UserDefaultsServiceType = UserDefaultsService(provider: self)
  lazy var userService: UserServiceType = UserService(provider: self)
}
```

## Conventions

ReactorKit suggests some conventions to write clean and concise code.

* A reactor should have the ServiceProvider as a first argument of an initializer.

    ```swift
    class MyViewReactor {
      init(provider: ServiceProviderType)
    }
    ```

* You must create a reactor outside of a view and pass it to the view's `reactor` property.

    **Bad**

    ```swift
    class MyView: UIView, View {
      init() {
        self.reactor = MyViewReactor()
      }
    }
    ```

    **Good**

    ```swift
    let view = MyView()
    view.reactor = MyViewReactor(provider: provider)
    ```

* The ServiceProvider should be created once and passed to the first-most View.

    ```swift
    let serviceProvider = ServiceProvider()
    let firstViewReactor = FirstViewReactor(provider: serviceProvider)
    window.rootViewController = FirstViewController(reactor: firstViewReactor)
    ```

## Examples

* [RxTodo](https://github.com/devxoul/RxTodo): iOS Todo Application using ReactorKit
* [Cleverbot](https://github.com/devxoul/Cleverbot): Cleverbot for iOS using ReactorKit
* [Drrrible](https://github.com/devxoul/Drrrible): Dribbble for iOS using ReactorKit

## Dependencies

* [RxSwift](https://github.com/ReactiveX/RxSwift) >= 3.0

## Requirements

* Swift 3
* iOS 8
* macOS 10.11
* tvOS 9.0
* watchOS 2.0

## Installation

* **Using [CocoaPods](https://cocoapods.org)**:

    ```ruby
    pod 'ReactorKit'
    ```

* **Using [Carthage](https://github.com/Carthage/Carthage)**:

    ```
    github "devxoul/ReactorKit" ~> 0.1
    ```

## Contribution

Any discussions and pull requests are welcomed 💖 

To contribute code, use `$ swift generate-xcodeproj` to generate Xcode project for development.

## Changelog

* 2017-04-18
    * Change the repository name to ReactorKit.
* 2017-03-17
    * Change the architecture name from RxMVVM to The Reactive Architecture.
    * Every ViewModels are renamed to ViewReactors.

## License

ReactorKit is under MIT license. See the [LICENSE](LICENSE) for more info.
