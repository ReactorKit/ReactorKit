# RxMVVM

RxMVVM is the modern and reactive architecture for RxSwift application. This repository introduces the basic concept of RxMVVM and describes how to build an application using RxMVVM.

⚠️ This document is currently in draft.

## Table of Contents

* [Basic Concept](#basic-concept)
* [Conventions](#conventions)
* [Building an Application](#building-an-application)
* [Resources](#resources)

## Basic Concept

RxMVVM is based on MVVM architecture. It uses RxSwift as a communication method between each layers: View, ViewModel and Model. For example, user interactions are delivered from View to ViewModel via `PublishSubject`. Data is exposed by normal properties or `Observable` properties. It depends on whether ViewModel can provide mutable property or not.

![mvvm](https://cloud.githubusercontent.com/assets/931655/22104896/c1f7dcfa-de84-11e6-991c-02c1a126b746.png)

ViewModel protocols usually have two types of property: *Input* and *Output*. This is an example ViewModel protocol. It's recommended to define ViewModel protocol before implementing it. It gives you more testability.

```swift
protocol ProfileViewModelType {
  // Input
  var followButtonDidTap: PublishSubject<Void> { get }
  // Output
  var isFollowButtonSelected: Driver<Void> { get }
}
```

### Service Layer

RxMVVM has a special layer named *Service*. Service layer does actual business logic such as networking. ViewModel is a middle layer which manages event streams. When ViewModel receives user input, ViewModel manipulates the event stream and pass it to Service. Service will make a network request, map the response to Model, then send it back to ViewModel.

![service](https://cloud.githubusercontent.com/assets/931655/22107072/5cb57fc2-de8f-11e6-8eee-07b564673a70.png)

Single ViewModel can communicate with many Services. *ServiceProvider* provides the references of Services to ViewModel. ServiceProvider is created once and passed to the first ViewModel. ViewModel should pass its ViewModel reference to child ViewModel.

## Conventions

RxMVVM suggests some conventions to write clean and concise code.

* View doesn't have control flow. View cannot modify the data. View only knows how to map the data.

    **Bad**

    ```swift
    viewModel.titleLabelText
      .map { $0 + "!" } // Bad: View should not modify the data
      .bindTo(self.titleLabel)
    ```

    **Good**
    
    ```swift
    viewModel.titleLabelText
      .bindTo(self.titleLabel.rx.text)
    ```

* View doesn't know what ViewModel does. View can only communicate to ViewModel about what View did.

    **Bad**

    ```swift
    viewModel.login() // Bad: View should not know what ViewModel does (login)
    ```

    **Good**
    
    ```swift
    self.loginButton.rx.tap
      .bindTo(viewModel.loginButtonDidTap) // "Hey I clicked the login button"

    self.usernameInput.rx.controlEvent(.editingDidEndOnExit)
      .bindTo(viewModel.usernameInputDidReturn) // "Hey I tapped the return on username input"
    ```

* Model is hidden by ViewModel. ViewModel only exposes the minimum data so that View can render.

    **Bad**
    
    ```swift
    struct ProductViewModel {
      let product: Driver<Product> // Bad: ViewModel should hide Model
    }
    ```

    **Good**
    
    ```swift
    struct ProductViewModel {
      let productName: Driver<String>
      let formattedPrice: Driver<String>
      let formattedOriginalPrice: Driver<String>
      let isOriginalPriceHidden: Driver<Bool>
    }
    ```

* Use Reactive extension to communicate between View and View. Then bind it to ViewModel.

    ![viewview](https://cloud.githubusercontent.com/assets/931655/22108435/7cfe76a6-de96-11e6-9f3f-e7c823f8f0e0.png)

    **MessageInputView.swift**

    ```swift
    extension Reactive where Base: MessageInputView {
      var sendButtonTap: ControlEvent<String?> { ... }
      var isSendButtonLoading: ControlEvent<String?> { ... }
    }
    ```

    **MessageListViewModel.swift**

    ```swift
    protocol MessageListViewModelType {
      // Input
      var messageInputViewSendButtonDidTap: PublishSubject<String?> { get }

      // Output
      var isMessageInputViewSendButtonLoading: Driver<Bool> { get }
    }
    ```

    **MessageListViewController.swift**

    ```swift
    func configure(viewModel: MessageListViewModelType) {
      // Input
      self.messageInputView.rx.sendButtonTap
        .bindTo(viewModel.messageInputViewSendButtonDidTap)
        .addDisposableTo(self.disposeBag)

      // Output
      viewModel.isMessageInputViewSendButtonLoading
        .drive(self.messageInputView.rx.isSendButtonLoading)
        .addDisposableTo(self.disposeBag)
    }
    ```

## Resources

* [RxTodo](https://github.com/devxoul/RxTodo): iOS Todo Application using RxMVVM architecture

## License

[Creative Commons Attribution 4.0 International license](http://creativecommons.org/licenses/by/4.0/)
