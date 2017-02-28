# RxMVVM

RxMVVM is the modern and reactive architecture for RxSwift application. This repository introduces the basic concept of RxMVVM and describes how to build an application using RxMVVM.

You may want to check [Resources](#resources) section first if you'd like to see the actual code.

## Table of Contents

* [Basic Concept](#basic-concept)
* [Components](#components)
    * [View](#view)
    * [ViewModel](#viewmodel)
    * [Model](#model)
    * [Service](#service)
    * [ServiceProvider](#service-provider)
* [Conventions](#conventions)
* [Advanced Usage](#advanced-usage)
    * [Presenting next ViewController](#presenting-next-viewcontroller)
    * [Communicating between ViewModel and ViewModel](#communicating-between-viewmodel-and-viewmodel)
* [Resources](#resources)
* [License](#license)

## Basic Concept

RxMVVM is based on MVVM architecture. It uses RxSwift as a communication method between each layers: *View*, *ViewModel* and *Model*. For example, user interactions are delivered from View to ViewModel via `PublishSubject`. Data is exposed by properties or `Observable` properties. It depends on whether ViewModel can provide mutable property or not.

<p align="center">
  <img alt="view-viewmodel-model" src="https://cloud.githubusercontent.com/assets/931655/22104896/c1f7dcfa-de84-11e6-991c-02c1a126b746.png" width="600">
</p>

## Components

### View

*View* refers to the component which displays data. In RxMVVM, a ViewController is treated as a View. A Cell is treated as a View as well.

A View only defines how to map the ViewModel's data to each UI components. These bindings are usually created in `configure()` method.

```swift
func configure(viewModel: MyViewModelType) {
  // Input
  self.button.rx.tap
    .bindTo(viewModel.buttonDidTap)
    .addDisposableTo(self.disposeBag)
  
  // Output
  viewModel.isButtonEnabled
    .drive(self.button.rx.isEnabled)
    .addDisposableTo(self.disposeBag)
}
```

It's recommended to define `configure()` as `private` or `fileprivate` if it's called only from the initializer. For example, every ViewController takes ViewModel in the initializer so `configure()` can be called in the initializer.

```swift
class ProfileViewController {
  init(viewModel: ProfileViewModelType) {
    super.init(nibName: nil, bundle: nil)
    self.configure(viewModel: viewModel)
  }
  
  private func configure(viewModel: ProfileViewModelType) {
    // ...
  }
}
```

On the other hand, the Cell's `configure()` method is called from outside such as `tableView(_:cellForRowAt:)`, or `configureCell` closure if you're using [RxDataSources](https://github.com/RxSwiftCommunity/RxDataSources).

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
  let cell = tableView.dequeueReusableCell(...)
  cell.configure(viewModel: viewModel)
  return cell
}
```

In order to manage Disposables, a View typically has its own DisposeBag.

```swift
class MyView: UIView {
  let disposeBag = DisposeBag()
}
```

### ViewModel

*ViewModel* receives user input and creates output so that View can bind it to its UI components. View usually has its corresponding ViewModel. For example, `ProfileViewController` has `ProfileViewModel`. ViewController should have its ViewModel but not all View should have its ViewModel.

ViewModel follows the naming convention of the corresponding View. Here are some examples:

| View | ViewModel |
|---|---|
| ProfileViewController | ProfileViewModel |
| CommentInputView | CommentInputViewModel |
| ArticleCardCell | ArticleCardCellModel |

ViewModel protocols have two types of property: *Input* and *Output*. This is an example ViewModel protocol. It's recommended to define ViewModel protocol before implementing it. It gives you more testability.

Inputs are usually defined as `PublishSubject` so that View can bind user inputs to ViewModel. Outputs are usually defined as `Driver` which ensures every events to be subscribed on the main thread.

```swift
protocol ProfileViewModelType {
  // Input
  var followButtonDidTap: PublishSubject<Void> { get }
  // Output
  var isFollowButtonSelected: Driver<Void> { get }
}
```

Alternatively, you can do as following if you'd like to separate inputs and outputs explicitly:

```swift
protocol ProfileViewModelInput {
  var followButtonDidTap: PublishSubject<Void> { get }
}
protocol ProfileViewModelOutput {
  var isFollowButtonSelected: Driver<Void> { get }
}
typealias ProfileViewModelType = ProfileViewModelInput & ProfileViewModelOutput
```

ViewModel should initialize inputs and outputs in the initializer.

```swift
class ProfileViewModel {
  // MARK: Input
  let followButtonDidTap = PublishSubject<Int>()
  
  // MARK: Output
  let isFollowButtonSelected: Driver<Void>
  
  // MARK: Init
  init(provider: ServiceProvider) {
    self.isFollowButtonSelected = self.followButtonDidTap
      .flatMap { (userID: Int) -> Observable<Void> in
        return provider.userService.follow(userID: userID).map { _ in true }
      }
      .asDriver(onErrorJustReturn: false)
  }
}
```

### Model

*Model* only represents data structure.

### Service

RxMVVM has a special layer named *Service*. Service layer does actual business logic such as networking. ViewModel is a middle layer which manages event streams. When ViewModel receives user input from View, ViewModel manipulates the event stream and passes it to Service. Service will make a network request, map the response to Model, then send it back to ViewModel.

<p align="center">
  <img alt="service-layer" src="https://cloud.githubusercontent.com/assets/931655/22107072/5cb57fc2-de8f-11e6-8eee-07b564673a70.png" width="600">
</p>

### Service Provider

Single ViewModel can communicate with many Services. *ServiceProvider* provides the references of Services to ViewModel. ServiceProvider is created once and passed to the first ViewModel. ViewModel should pass its ViewModel reference to child ViewModel.

```swift
let serviceProvider = ServiceProvider()
let firstViewModel = FirstViewModel(provider: serviceProvider)
let firstViewController = FirstViewController(viewModel: firstViewModel)
window.rootViewController = firstViewController
```

ServiceProvider is not complicated. Here is an example code of ServiceProvider:

```swift
protocol ServiceProviderType: class {
  var userService: UserServiceType { get }
  var articleService: ArticleServiceType { get }
}

final class ServiceProvider: ServiceProviderType {
  lazy var userService: UserServiceType = UserService(provider: self)
  lazy var articleService: ArticleServiceType = ArticleService(provider: self)
}
```

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

## Advanced Usage

This chapter describes some architectural considerations.

### Presenting next ViewController

Almost applications have more than one ViewController.  In MVC architecture, ViewController(`ListViewController`) creates next ViewController(`DetailViewController`) and just presents it. This is same in RxMVVM but the only difference is the creation of ViewModel.

In RxMVVM, `ListViewModel` creates `DetailViewModel` and passes it to `ListViewController`. Then the `ListViewController` creates `DetailViewController` with the `DetailViewModel` received from `ListViewModel`.

Here is an example code of `ListViewModel`:

```swift
class ListViewModel: ListViewModelType {
  // MARK: Input
  let detailButtonDidTap: PublishSubject<Void> = .init()
  
  // MARK: Output
  let presentDetailViewModel: Observable<DetailViewModelType>

  // MARK: Init
  init(provider: ServiceProviderType) {
    self.presentDetailViewModel = self.detailButtonDidTap
      .map { _ -> DetailViewModelType in
        return DetailViewModel(provider: provider)
      }
  }
}
```

And `ListViewController`:

```swift
class ListViewController: UIViewController {
  private func configure(viewModel: ListViewModelType) {
    // Output
    viewModel.detailViewModel
      .subscribe(onNext: { viewModel in
        let detailViewController = DetailViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(detailViewController, animated: true)
      })
      .addDisposableTo(self.disposeBag)
  }
}
```

### Communicating between ViewModel and ViewModel

Sometimes ViewModel should receive data (such as user input) from the other ViewModel. In this case, use `rx` extension to communicate between View and View. Then bind it to ViewModel.
    
<p align="center">
  <img alt="viewmodel-viewmodel" src="https://cloud.githubusercontent.com/assets/931655/23399004/f12ee49c-fde1-11e6-95b2-1df397128c51.png" width="600">
</p>

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
