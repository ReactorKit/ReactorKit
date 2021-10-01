<img alt="ReactorKit" src="https://cloud.githubusercontent.com/assets/931655/25277625/6aa05998-26da-11e7-9b85-e48bec938a6e.png" style="max-width: 100%">

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-orange.svg">
  <a href="https://cocoapods.org/pods/ReactorKit" target="_blank">
    <img alt="CocoaPods" src="http://img.shields.io/cocoapods/v/ReactorKit.svg">
  </a>
  <a href="https://github.com/ReactorKit/ReactorKit" target="_blank">
    <img alt="Platform" src="https://img.shields.io/cocoapods/p/ReactorKit.svg?style=flat">
  </a>
  <a href="https://github.com/ReactorKit/ReactorKit/actions" target="_blank">
    <img alt="CI" src="https://github.com/ReactorKit/ReactorKit/workflows/CI/badge.svg">
  </a>
  <a href="https://codecov.io/gh/ReactorKit/ReactorKit/" target="_blank">
    <img alt="Codecov" src="https://img.shields.io/codecov/c/github/ReactorKit/ReactorKit.svg">
  </a>
</p>

ReactorKit is a framework for a reactive and unidirectional Swift application architecture. This repository introduces the basic concept of ReactorKit and describes how to build an application using ReactorKit.

You may want to see the [Examples](#examples) section first if you'd like to see the actual code. For an overview of ReactorKit's features and the reasoning behind its creation, you may also check the slides from this introductory presentation over at [SlideShare](https://www.slideshare.net/devxoul/hello-reactorkit).

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Basic Concept](#basic-concept)
  - [Design Goal](#design-goal)
  - [View](#view)
    - [Storyboard Support](#storyboard-support)
  - [Reactor](#reactor)
    - [`mutate()`](#mutate)
    - [`reduce()`](#reduce)
    - [`transform()`](#transform)
- [Advanced](#advanced)
  - [Global States](#global-states)
  - [View Communication](#view-communication)
  - [Testing](#testing)
    - [What to test](#what-to-test)
    - [View testing](#view-testing)
    - [Reactor testing](#reactor-testing)
  - [Scheduling](#scheduling)
  - [Pulse](#pulse)
- [Examples](#examples)
- [Dependencies](#dependencies)
- [Requirements](#requirements)
- [Installation](#installation)
- [Contribution](#contribution)
- [Community](#community)
  - [Join](#join)
  - [Community Projects](#community-projects)
- [Who's using ReactorKit](#whos-using-reactorkit)
- [Changelog](#changelog)
- [License](#license)

## Basic Concept

ReactorKit is a combination of [Flux](https://facebook.github.io/flux/) and [Reactive Programming](https://en.wikipedia.org/wiki/Reactive_programming). The user actions and the view states are delivered to each layer via observable streams. These streams are unidirectional: the view can only emit actions and the reactor can only emit states.

<p align="center">
  <img alt="flow" src="https://cloud.githubusercontent.com/assets/931655/25073432/a91c1688-2321-11e7-8f04-bf91031a09dd.png" width="600">
</p>

### Design Goal

* **Testability**: The first purpose of ReactorKit is to separate the business logic from a view. This can make the code testable. A reactor doesn't have any dependency to a view. Just test reactors and test view bindings. See [Testing](#testing) section for details.
* **Start Small**: ReactorKit doesn't require the whole application to follow a single architecture. ReactorKit can be adopted partially, for one or more specific views. You don't need to rewrite everything to use ReactorKit on your existing project.
* **Less Typing**: ReactorKit focuses on avoiding complicated code for a simple thing. ReactorKit requires less code compared to other architectures. Start simple and scale up.

### View

A *View* displays data. A view controller and a cell are treated as a view. The view binds user inputs to the action stream and binds the view states to each UI component. There's no business logic in a view layer. A view just defines how to map the action stream and the state stream.

To define a view, just have an existing class conform a protocol named `View`. Then your class will have a property named `reactor` automatically. This property is typically set outside of the view.

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
    .bind(to: reactor.action)
    .disposed(by: self.disposeBag)

  // state (Reactor -> View)
  reactor.state.map { $0.isFollowing }
    .bind(to: followButton.rx.isSelected)
    .disposed(by: self.disposeBag)
}
```

#### Storyboard Support

Use `StoryboardView` protocol if you're using a storyboard to initialize view controllers. Everything is same but the only difference is that the `StoryboardView` performs a binding after the view is loaded.

```swift
let viewController = MyViewController()
viewController.reactor = MyViewReactor() // will not executes `bind(reactor:)` immediately

class MyViewController: UIViewController, StoryboardView {
  func bind(reactor: MyViewReactor) {
    // this is called after the view is loaded (viewDidLoad)
  }
}
```

### Reactor

A *Reactor* is an UI-independent layer which manages the state of a view. The foremost role of a reactor is to separate control flow from a view. Every view has its corresponding reactor and delegates all logic to its reactor. A reactor has no dependency to a view, so it can be easily tested.

Conform to the `Reactor` protocol to define a reactor. This protocol requires three types to be defined: `Action`, `Mutation` and `State`. It also requires a property named `initialState`.

```swift
class ProfileViewReactor: Reactor {
  // represent user actions
  enum Action {
    case refreshFollowingStatus(Int)
    case follow(Int)
  }

  // represent state changes
  enum Mutation {
    case setFollowing(Bool)
  }

  // represents the current view state
  struct State {
    var isFollowing: Bool = false
  }

  let initialState: State = State()
}
```

An `Action` represents a user interaction and `State` represents a view state. `Mutation` is a bridge between `Action` and `State`. A reactor converts the action stream to the state stream in two steps: `mutate()` and `reduce()`.

<p align="center">
  <img alt="flow-reactor" src="https://cloud.githubusercontent.com/assets/931655/25098066/2de21a28-23e2-11e7-8a41-d33d199dd951.png" width="800">
</p>

#### `mutate()`

`mutate()` receives an `Action` and generates an `Observable<Mutation>`.

```swift
func mutate(action: Action) -> Observable<Mutation>
```

Every side effect, such as an async operation or API call, is performed in this method.

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

`reduce()` generates a new `State` from a previous `State` and a `Mutation`.

```swift
func reduce(state: State, mutation: Mutation) -> State
```

This method is a pure function. It should just return a new `State` synchronously. Don't perform any side effects in this function.

```swift
func reduce(state: State, mutation: Mutation) -> State {
  var state = state // create a copy of the old state
  switch mutation {
  case let .setFollowing(isFollowing):
    state.isFollowing = isFollowing // manipulate the state, creating a new state
    return state // return the new state
  }
}
```

#### `transform()`

`transform()` transforms each stream. There are three `transform()` functions:

```swift
func transform(action: Observable<Action>) -> Observable<Action>
func transform(mutation: Observable<Mutation>) -> Observable<Mutation>
func transform(state: Observable<State>) -> Observable<State>
```

Implement these methods to transform and combine with other observable streams. For example, `transform(mutation:)` is the best place for combining a global event stream to a mutation stream. See the [Global States](#global-states) section for details.

These methods can be also used for debugging purposes:

```swift
func transform(action: Observable<Action>) -> Observable<Action> {
  return action.debug("action") // Use RxSwift's debug() operator
}
```

## Advanced

### Global States

Unlike Redux, ReactorKit doesn't define a global app state. It means that you can use anything to manage a global state. You can use a `BehaviorSubject`, a `PublishSubject` or even a reactor. ReactorKit doesn't force to have a global state so you can use ReactorKit in a specific feature in your application.

There is no global state in the **Action → Mutation → State** flow. You should use `transform(mutation:)` to transform the global state to a mutation. Let's assume that we have a global `BehaviorSubject` which stores the current authenticated user. If you'd like to emit a `Mutation.setUser(User?)` when the `currentUser` is changed, you can do as following:


```swift
var currentUser: BehaviorSubject<User> // global state

func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
  return Observable.merge(mutation, currentUser.map(Mutation.setUser))
}
```

Then the mutation will be emitted each time the view sends an action to a reactor and the `currentUser` is changed.

### View Communication

You must be familiar with callback closures or delegate patterns for communicating between multiple views. ReactorKit recommends you to use [reactive extensions](https://github.com/ReactiveX/RxSwift/blob/master/RxSwift/Reactive.swift) for it. The most common example of `ControlEvent` is `UIButton.rx.tap`. The key concept is to treat your custom views as UIButton or UILabel.

<p align="center">
  <img alt="view-view" src="https://user-images.githubusercontent.com/931655/27789114-393e2eea-6026-11e7-9b32-bae314e672ee.png" width="600">
</p>

Let's assume that we have a `ChatViewController` which displays messages. The `ChatViewController` owns a `MessageInputView`. When an user taps the send button on the `MessageInputView`, the text will be sent to the `ChatViewController` and `ChatViewController` will bind in to the reactor's action. This is an example `MessageInputView`'s reactive extension:

```swift
extension Reactive where Base: MessageInputView {
  var sendButtonTap: ControlEvent<String> {
    let source = base.sendButton.rx.tap.withLatestFrom(...)
    return ControlEvent(events: source)
  }
}
```

You can use that extension in the `ChatViewController`. For example:

```swift
messageInputView.rx.sendButtonTap
  .map(Reactor.Action.send)
  .bind(to: reactor.action)
```

### Testing

ReactorKit has a built-in functionality for a testing. You'll be able to easily test both a view and a reactor with a following instruction.

#### What to test

First of all, you have to decide what to test. There are two things to test: a view and a reactor.

* View
    * Action: is a proper action sent to a reactor with a given user interaction?
    * State: is a view property set properly with a following state?
* Reactor
    * State: is a state changed properly with an action?

#### View testing

A view can be tested with a *stub* reactor. A reactor has a property `stub` which can log actions and force change states. If a reactor's stub is enabled, both `mutate()` and `reduce()` are not executed. A stub has these properties:

```swift
var state: StateRelay<Reactor.State> { get }
var action: ActionSubject<Reactor.Action> { get }
var actions: [Reactor.Action] { get } // recorded actions
```

Here are some example test cases:

```swift
func testAction_refresh() {
  // 1. prepare a stub reactor
  let reactor = MyReactor()
  reactor.isStubEnabled = true

  // 2. prepare a view with a stub reactor
  let view = MyView()
  view.reactor = reactor

  // 3. send an user interaction programatically
  view.refreshControl.sendActions(for: .valueChanged)

  // 4. assert actions
  XCTAssertEqual(reactor.stub.actions.last, .refresh)
}

func testState_isLoading() {
  // 1. prepare a stub reactor
  let reactor = MyReactor()
  reactor.isStubEnabled = true

  // 2. prepare a view with a stub reactor
  let view = MyView()
  view.reactor = reactor

  // 3. set a stub state
  reactor.stub.state.value = MyReactor.State(isLoading: true)

  // 4. assert view properties
  XCTAssertEqual(view.activityIndicator.isAnimating, true)
}
```

#### Reactor testing

A reactor can be tested independently.

```swift
func testIsBookmarked() {
  let reactor = MyReactor()
  reactor.action.onNext(.toggleBookmarked)
  XCTAssertEqual(reactor.currentState.isBookmarked, true)
  reactor.action.onNext(.toggleBookmarked)
  XCTAssertEqual(reactor.currentState.isBookmarked, false)
}
```

Sometimes a state is changed more than one time for a single action. For example, a `.refresh` action sets `state.isLoading` to `true` at first and sets to `false` after the refreshing. In this case it's difficult to test `state.isLoading` with `currentState` so you might need to use [RxTest](https://github.com/ReactiveX/RxSwift) or [RxExpect](https://github.com/devxoul/RxExpect). Here is an example test case using RxSwift:

```swift
func testIsLoading() {
  // given
  let scheduler = TestScheduler(initialClock: 0)
  let reactor = MyReactor()
  let disposeBag = DisposeBag()

  // when
  scheduler
    .createHotObservable([
      .next(100, .refresh) // send .refresh at 100 scheduler time
    ])
    .subscribe(reactor.action)
    .disposed(by: disposeBag)

  // then
  let response = scheduler.start(created: 0, subscribed: 0, disposed: 1000) {
    reactor.state.map(\.isLoading)
  }
  XCTAssertEqual(response.events.map(\.value.element), [
    false, // initial state
    true,  // just after .refresh
    false  // after refreshing
  ])
}
```

### Scheduling

Define `scheduler` property to specify which scheduler is used for reducing and observing the state stream. Note that this queue **must be** a serial queue. The default scheduler is `CurrentThreadScheduler`.

```swift
final class MyReactor: Reactor {
  let scheduler: Scheduler = SerialDispatchQueueScheduler(qos: .default)

  func reduce(state: State, mutation: Mutation) -> State {
    // executed in a background thread
    heavyAndImportantCalculation()
    return state
  }
}
```

### Pulse

`Pulse` has diff only when mutated
To explain in code, the results are as follows.
```swift
var messagePulse: Pulse<String?> = Pulse(wrappedValue: "Hello tokijh")

let oldMessagePulse: Pulse<String?> = message
message = "Hello tokijh"

oldMessagePulse != messagePulse // true
oldMessagePulse.value == messagePulse.value // true
```

Use when you want to receive an event only if the new value is assigned, even if it is the same value.
like `alertMessage` (See follows or [PulseTests.swift](https://github.com/ReactorKit/ReactorKit/blob/master/Tests/ReactorKitTests/PulseTests.swift))
```swift
// Reactor
private final class MyReactor: Reactor {
  struct State {
    @Pulse var alertMessage: String?
  }

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .alert(message):
      return Observable.just(Mutation.setAlertMessage(message))
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
    case let .setAlertMessage(alertMessage):
      newState.alertMessage = alertMessage
    }

    return newState
  }
}

// View
reactor.pulse(\.$alertMessage)
  .compactMap { $0 } // filter nil
  .subscribe(onNext: { [weak self] (message: String) in
    self?.showAlert(message)
  })
  .disposed(by: disposeBag)

// Cases
reactor.action.onNext(.alert("Hello"))  // showAlert() is called with `Hello`
reactor.action.onNext(.alert("Hello"))  // showAlert() is called with `Hello`
reactor.action.onNext(.doSomeAction)    // showAlert() is not called
reactor.action.onNext(.alert("Hello"))  // showAlert() is called with `Hello`
reactor.action.onNext(.alert("tokijh")) // showAlert() is called with `tokijh`
reactor.action.onNext(.doSomeAction)    // showAlert() is not called
```

## Examples

* [Counter](https://github.com/ReactorKit/ReactorKit/tree/master/Examples/Counter): The most simple and basic example of ReactorKit
* [GitHub Search](https://github.com/ReactorKit/ReactorKit/tree/master/Examples/GitHubSearch): A simple application which provides a GitHub repository search
* [RxTodo](https://github.com/devxoul/RxTodo): iOS Todo Application using ReactorKit
* [Cleverbot](https://github.com/devxoul/Cleverbot): iOS Messaging Application using Cleverbot and ReactorKit
* [Drrrible](https://github.com/devxoul/Drrrible): Dribbble for iOS using ReactorKit ([App Store](https://itunes.apple.com/us/app/drrrible/id1229592223?mt=8))
* [Passcode](https://github.com/cruisediary/Passcode): Passcode for iOS RxSwift, ReactorKit and IGListKit example
* [Flickr Search](https://github.com/TaeJoongYoon/FlickrSearch): A simple application which provides a Flickr Photo search with RxSwift and ReactorKit
* [ReactorKitExample](https://github.com/gre4ixin/ReactorKitExample)
* [reactorkit-keyboard-example](https://github.com/techinpark/reactorkit-keyboard-example): iOS Application example for develop keyboard-extensions using ReactorKit Architecture.
* [SWHub](https://github.com/tospery/SWHub): Use ReactorKit develop the Github client

## Dependencies

* [RxSwift](https://github.com/ReactiveX/RxSwift) >= 5.0

## Requirements

* Swift 5
* iOS 8
* macOS 10.11
* tvOS 9.0
* watchOS 2.0

## Installation

ReactorKit officially supports CocoaPods only.

**Podfile**

```ruby
pod 'ReactorKit'
```

ReactorKit does not officially support Carthage.

**Cartfile**

```swift
github "ReactorKit/ReactorKit"
```

Most Carthage installation issues can be resolved with the following:
```sh
carthage update 2>/dev/null
(cd Carthage/Checkouts/ReactorKit && swift package generate-xcodeproj)
carthage build
```

## Contribution

Any discussions and pull requests are welcomed 💖

* To development:

    ```console
    $ TEST=1 swift package generate-xcodeproj
    ```

* To test:

    ```console
    $ swift test
    ```

## Community

### Join

* **English**: Join [#reactorkit](https://rxswift.slack.com/messages/C561PETRN/) on [RxSwift Slack](http://rxswift-slack.herokuapp.com/)
* **Korean**: Join [#reactorkit](https://swiftkorea.slack.com/messages/C568YM2RF/) on [Swift Korea Slack](http://slack.swiftkorea.org/)

### Community Projects

* [ReactorKit-Template](https://github.com/gre4ixin/ReactorKit-Template)

## Who's using ReactorKit

<p align="center">
  <br>
  <a href="https://www.stylesha.re"><img align="center" height="48" alt="StyleShare" hspace="15" src="https://user-images.githubusercontent.com/931655/30255218-e16fedfe-966f-11e7-973d-7d8d1726d7f6.png"></a>
  <a href="http://www.kakaocorp.com"><img align="center" height="36" alt="Kakao" hspace="15" src="https://user-images.githubusercontent.com/931655/30324656-cbea148a-97fc-11e7-9101-ba38d50f08f4.png"></a>
  <a href="https://www.wantedly.com"><img align="center" height="48" alt="Wantedly" hspace="15" src="https://user-images.githubusercontent.com/5885032/123386862-12314780-d5d2-11eb-91c6-f9dc14a329f0.png"></a>
  <br><br>
  <a href="http://getdoctalk.com"><img align="center" height="48" alt="DocTalk" hspace="15" src="https://user-images.githubusercontent.com/931655/30633896-503d142c-9e28-11e7-8e67-69c2822efe77.png"></a>
  <a href="https://www.constantcontact.com"><img align="center" height="44" alt="Constant Contact" hspace="15" src="https://user-images.githubusercontent.com/931655/43634090-2cb30c7e-9746-11e8-8e18-e4fcf87a08cc.png"></a>
  <a href="https://www.kt.com"><img align="center" height="42" alt="KT" hspace="15" src="https://user-images.githubusercontent.com/931655/43634093-2ec9e94c-9746-11e8-9213-75c352e0c147.png"></a>
  <br><br>
  <a href="https://hyperconnect.com/"><img align="center" height="62" alt="Hyperconnect" hspace="15" src="https://user-images.githubusercontent.com/931655/50819891-aa89d200-136e-11e9-8b19-780e64e54b2a.png"></a>
  <a href="https://toss.im/career/?category=engineering&positionId=7"><img align="center" height="28" alt="Toss" hspace="15" src="https://user-images.githubusercontent.com/931655/65512318-ede39b00-df13-11e9-874c-f1e478bda6c8.png"></a>
  <a href="https://pay.line.me"><img align="center" height="58" alt="LINE Pay" hspace="15" src="https://user-images.githubusercontent.com/68603/68569839-7efdd980-04a2-11ea-8d7e-673831b1b658.png"></a>
  <br><br>
  <a href="https://www.gccompany.co.kr/"><img align="center" height="45" alt="LINE Pay" hspace="15" src="https://user-images.githubusercontent.com/931655/84870371-32beeb80-b0ba-11ea-8530-0dc71c4e385e.png"></a>
  <br><br>
</p>

> Are you using ReactorKit? Please [let me know](mailto:devxoul+reactorkit@gmail.com)!

## Changelog

* 2017-04-18
    * Change the repository name to ReactorKit.
* 2017-03-17
    * Change the architecture name from RxMVVM to The Reactive Architecture.
    * Every ViewModels are renamed to ViewReactors.

## License

ReactorKit is under MIT license. See the [LICENSE](https://github.com/ReactorKit/ReactorKit/blob/master/LICENSE) for more info.
