# ReactorKit - Pulse

Today we're going to talk about a Pulse in ReactorKit.

Added to version 3.1.0 and partially modified from version 3.2.0, the most recent version of the current (2022.04.08).

> 3.1.0             
...
Introduce Pulse 📡 (@tokijh)            

> 3.2.0 Latest      
...     
Make public valueUpdatedCount on Pulse by @tokijh in #196           

In fact, Pulse is currently being used for in-company projects, and I'm writing this because I'm not sure what this means.I think we can find out one by one.😁

First, let's look at the documents.

[The official document](https://github.com/ReactorKit/ReactorKit#pulse) introduces Pulse like this.

> Pulse has diff only when mutated To explain in code, the results are as follows.

Well... I see.I didn't get it.

"shall we look at the code?"

```swift
  var messagePulse: Pulse<String?> = Pulse(wrappedValue: "Hello tokijh")

  let oldMessagePulse: Pulse<String?> = message
  message = "Hello tokijh"

  oldMessagePulse != messagePulse // true
  oldMessagePulse.value == messagePulse.value // true
```

Well... what is it?
This looks similar to [distinctUntilChanged](https://reactivex.io/documentation/operators/distinct.html) operator in RxSwift in my think.

and I took the code and ran it in xcode.

<img width="1088" alt="image" src="https://user-images.githubusercontent.com/85085822/162379923-b3ae5b31-be7c-4bda-8ed8-91b643448ea6.png">

Well, there's an error...( An error-free modified code is at the end.)

If so, we'll have no choice but to look at the following documents:

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

Looking at the `// Cases`, perhaps something similar to '[distinctUntilChanged](https://reactivex.io/documentation/operators/distinct.html)' is correct.


```swift
@propertyWrapper
public struct Pulse<Value> {

  public var value: Value {
    didSet {
      self.riseValueUpdatedCount()
    }
  }
  public internal(set) var valueUpdatedCount = UInt.min

  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    get { return self.value }
    set { self.value = newValue }
  }

  public var projectedValue: Pulse<Value> {
    return self
  }

  private mutating func riseValueUpdatedCount() {
    self.valueUpdatedCount &+= 1 
  }
}
```

The code for Pulse is as above. Genetic structure and `PropertyWrapper` has characteristics. If you want to know more about `PropertyWrapper`, you can look at [the official document](https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md)

Actually, I didn't get it at first, but the important part is `var value` and `didSet`.Every time `the value` changes, it does something specific. The work is as follows.

```swift
  private mutating func riseValueUpdatedCount() {
    self.valueUpdatedCount &+= 1 
  }
```

Whenever `the value` changes, the count `valueUpdatedCount` is +1. And if the `valueUpdatedCount` is UInt.max, we are assigning UInt.min back to the `valueUpdatedCount`.That's all. Shall we move on?

```swift
extension Reactor {
  public func pulse<Result>(_ transformToPulse: @escaping (State) throws -> Pulse<Result>) -> Observable<Result> {
    return self.state.map(transformToPulse).distinctUntilChanged(\.valueUpdatedCount).map(\.value)
  }
}
```

If you look at the code above, that's added a method `func pulse` as an extension to the Reactor. and used `distinctUntilChanged` in operator in RxSwift.

The operator is the one that receives the keySelector as a parameter among the four supported by RxSwift. 

```swift
  public func distinctUntilChanged<Key: Equatable>(_ keySelector: @escaping (Element) throws -> Key)
      -> Observable<Element> {
      self.distinctUntilChanged(keySelector, comparer: { $0 == $1 })
  }
```

usually use is as follows.

```swift
  struct Human {
    let name: String
    let age: Int
  }

  let myPublishSubject = PublishSubject<Human>.init()

  myPublishSubject
    .distinctUntilChanged(\.name)
    .debug()
    .subscribe()
    .disposed(by: disposeBag)

  myPublishSubject.onNext(Human(name: "a", age: 1))
  myPublishSubject.onNext(Human(name: "a", age: 2))
  myPublishSubject.onNext(Human(name: "c", age: 3))

  //-> subscribed
  //-> Event next(Human(name: "a", age: 1))
  //-> Event next(Human(name: "c", age: 3))
```
So if you summarize it here, ***`Pulse` emits events, but only when the values of the variables `valueUpdatedCount` declared inside change.***

So when will the value of `valueUpdatedCount`change? As mentioned above, this is when `value` changes.

The official document of ReactorKit provides additional explanations and examples as below.

> Use when you want to receive an event only if the new value is assigned, even if it is the same value. like alertMessage (See follows or PulseTests.swift)

The most important part is `if the new value is assigned`. That is, the stream does not emit events unless a new value is assigned. 

Let's look at an additional [example](https://github.com/ReactorKit/ReactorKit/blob/master/Tests/ReactorKitTests/PulseTests.swift).

```swift
import XCTest
import RxSwift
@testable import ReactorKit

final class PulseTests: XCTestCase {
  func testRiseValueUpdatedCountWhenSetNewValue() {
    // given
    struct State {
      @Pulse var value: Int = 0
    }

    var state = State()

    // when & then
    XCTAssertEqual(state.$value.valueUpdatedCount, 0)
    state.value = 10
    XCTAssertEqual(state.$value.valueUpdatedCount, 1)
    XCTAssertEqual(state.$value.valueUpdatedCount, 1) // same count because no new values are assigned.
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 2)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 3)
    state.value = 20
    XCTAssertEqual(state.$value.valueUpdatedCount, 4)
    XCTAssertEqual(state.$value.valueUpdatedCount, 4) // same count because no new values are assigned.
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 5)
    state.value = 30
    XCTAssertEqual(state.$value.valueUpdatedCount, 6)
  }
```
The test is kindly annotated. It says `// same count because no new values are assigned.`. 

***i.e. the value of `valueUpdatedCount` is not incremented because we didn't assign a new value to the value like `state.value = 2` , and consequently `Pulse` will not emit any events.***

So, Pulse, how to use it? Again, as kindly described in the documentation, attach `@Pulse` attribute to `State` and import it in the same way as `reactor.pulse(\.$alertMessage)` inside func bind(reactor:).

```swift
  struct State {
    @Pulse var alertMessage: String?
  }

  // View
  reactor.pulse(\.$alertMessage)
    .compactMap { $0 } // filter nil
    .subscribe(onNext: { [weak self] (message: String) in
      self?.showAlert(message)
    })
    .disposed(by: disposeBag)
```

In conclusion, the official document above should be partially revised as below, right?

```swift
  var messagePulse: Pulse<String?> = Pulse(wrappedValue: "Hello tokijh")

  let oldMessagePulse: Pulse<String?> = messagePulse
  messagePulse.value = "Hello tokijh" // add valueUpdatedCount +1

  oldMessagePulse.valueUpdatedCount != messagePulse.valueUpdatedCount // true
  oldMessagePulse.value == messagePulse.value // true
```

Insert messagePulse into oldMessagePulse and assign a new value to the value of the messagePulse.

If you do that, `the values` of oldMessagePulse and messagePulse are the same, but valueUpdatedCount is +1 as the value is assigned, so `the valueUpdatedCount` of oldMessagePulse and messagePulse is not the same.

Above, we learned about `Pulse` in `Reactorkit`. I was a little confused because I didn't know what it means to use it, but I hope that people who read this article will find it helpful. 😊

thank you.
