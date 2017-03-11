# RxMVVM

RxMVVM is the modern and reactive architecture for RxSwift application. This repository introduces the basic concept of RxMVVM and describes how to build an application using RxMVVM.

You may want to check [Examples](#examples) section first if you'd like to see the actual code.

## Table of Contents

* [Basic Concept](#basic-concept)
* [Layers](#layers)
    * [View](#view)
    * [ViewModel](#viewmodel)
    * [Model](#model)
    * [Service](#service)
    * [ServiceProvider](#serviceprovider)
* [Conventions](#conventions)
* [Advanced Usage](#advanced-usage)
    * [Presenting next ViewController](#presenting-next-viewcontroller)
    * [Communicating between ViewModel and ViewModel](#communicating-between-viewmodel-and-viewmodel)
* [Examples](#examples)
* [License](#license)

## Basic Concept

RxMVVM is a variation of traditional MVVM architecture. It uses [RxSwift](https://github.com/ReactiveX/RxSwift) as a communication method between each layers: *View*, *ViewModel* and *Service*. For example, user interactions are delivered from the View to the ViewModel via `PublishSubject`. The ViewModel exposes output data with Observables.

<p align="center">
  <img alt="view-viewmodel-model" src="https://cloud.githubusercontent.com/assets/931655/22104896/c1f7dcfa-de84-11e6-991c-02c1a126b746.png" width="600">
</p>

## Layers

### View

*View* displays data. In RxMVVM, a ViewController and a Cell are treated as View. The View only defines how to deliver user inputs to the ViewModel and how to map the ViewModel's output data to each UI components. It is recommended to not have business logic in the View. Sometimes it is allowed to have business logic for transitions or animations.

### ViewModel

*ViewModel* receives and process user inputs and creates output. The ViewModel has two types of property: *Input* and *Output*. The Input property represents the exact user input occured in the View. For example, the Input property is formed like `loginButtonDidTap` rather than `login()`. The Output property provides the primitive data so that the View can bind it to the UI components without converting values.

ViewModel **must not** have the reference of the View instance. However, in order to provide primitive data, ViewModel knows the indirect information about which values the View needs.

### Model

*Model* only represents data structure. The Model **should not** have any business logic except serialization and deserialization.

### Service

RxMVVM has a special layer named *Service*. Service layer does actual business logic such as networking. The ViewModel is a middle layer which manages event streams. When the ViewModel receives user inputs from the View, the ViewModel manipulates and compose the event streams and passes them to the Service. Then the Service makes a network request, maps the response to the Model, and send it back to the ViewModel.

<p align="center">
  <img alt="service-layer" src="https://cloud.githubusercontent.com/assets/931655/22107072/5cb57fc2-de8f-11e6-8eee-07b564673a70.png" width="600">
</p>

### ServiceProvider

A single ViewModel can communicate with many Services. *ServiceProvider* provides the references of the Services to the ViewModel. The ServiceProvider is created once in the whole application life cycle and passed to the first ViewModel. The first ViewModel should pass the same reference of the ServiceProvider instance to the child ViewModel.

## Conventions

RxMVVM suggests some conventions to write clean and concise code.

* You should use `PublishSubject` for Input properties and `Driver` for Output properties.

    ```swift
    protocol MyViewModelType {
      // Input
      var loginButtonDidTap: PublishSubject<Void> { get }

      // Output
      var isLoginButtonEnabled: Driver<Bool> { get } 
    }
    ```

* ViewModel should have the ServiceProvider as the initializer's first argument.

    ```swift
    class MyViewModel {
      init(provider: ServiceProviderType)
    }
    ```

* You must create a ViewModel outside of the View. Pass the ViewModel to the initializer if the View is not reusable. Pass the ViewModel to the `configure(viewModel:)` method if the View is reusable.

    **Bad**

    ```swift
    class MyViewController {
      let viewModel = MyViewModel()
    }
    ```

    **Good**

    ```swift
    let viewModel = MyViewModel(provider: provider)
    let viewController = MyViewController(viewModel: viewModel)
    ```

* The ServiceProvider should be created and passed to the first-most View.

    ```swift
    let serviceProvider = ServiceProvider()
    let firstViewModel = FirstViewModel(provider: serviceProvider)
    window.rootViewController = FirstViewController(viewModel: firstViewModel)
    ```

* The View should not have control flow. It means that the View cannot modify the data. The View only knows how to map the data.

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

* The View should not know what the ViewModel does. The View can only communicate to ViewModel about what the View did.

    **Bad**

    ```swift
    protocol MyViewModelType {
      // Bad: View know what the ViewModel does (login)
      var login: PublishSubject<Void> { get }
    }
    ```

    **Goods**

    ```swift
    protocol MyViewModelType {
      // View just say "Hey I clicked the login button"
      var loginButtonDidTap: PublishSubject<Void> { get }
    }
    ```

* The ViewModel should hide the Model. The ViewModel only exposes the minimum data so that the View can render.

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

* You should use protocols to have loose dependency. Usually the ViewModel, Service and ServiceProvider have its corresponding protocols.

    ```swift
    protocol ServiceProviderType {
      var userDefaultsService: UserDefaultServiceType { get }
      var keychainService: KeychainServiceType { get }
      var authService: AuthServiceType { get }
      var userService: UserServiceType { get }
    }
    ```

    ```swift
    protocol UserServiceType {
      func user(id: Int) -> Observable<User>
      func updateUser(id: Int, name: String?) -> Observable<User>
      func followUser(id: Int) -> Observable<Void>
    }
    ```

## Advanced Usage

This chapter describes some architectural considerations for real world.

### Presenting next ViewController

Almost applications have more than one ViewController.  In MVC architecture, ViewController(`ListViewController`) creates next ViewController(`DetailViewController`) and just presents it. This is same in RxMVVM but the only difference is the creation of ViewModel.

In RxMVVM, `ListViewModel` creates `DetailViewModel` and passes it to `ListViewController`. Then the `ListViewController` creates `DetailViewController` with the `DetailViewModel` received from `ListViewModel`.

* **ListViewModel**

    ```swift
    class ListViewModel: ListViewModelType {
      // MARK: Input
      let detailButtonDidTap: PublishSubject<Void> = .init()

      // MARK: Output
      let presentDetailViewModel: Observable<DetailViewModelType> // No Driver here

      // MARK: Init
      init(provider: ServiceProviderType) {
        self.presentDetailViewModel = self.detailButtonDidTap
          .map { _ -> DetailViewModelType in
            return DetailViewModel(provider: provider)
          }
      }
    }
    ```

* **ListViewController**

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

* **MessageInputView.swift**

    ```swift
    extension Reactive where Base: MessageInputView {
      var sendButtonTap: ControlEvent<String?> { ... }
      var isSendButtonLoading: ControlEvent<String?> { ... }
    }
    ```

* **MessageListViewModel.swift**

    ```swift
    protocol MessageListViewModelType {
      // Input
      var messageInputViewSendButtonDidTap: PublishSubject<String?> { get }

      // Output
      var isMessageInputViewSendButtonLoading: Driver<Bool> { get }
    }
    ```

* **MessageListViewController.swift**

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

## Examples

* [RxTodo](https://github.com/devxoul/RxTodo): iOS Todo Application using RxMVVM architecture
* [Cleverbot](https://github.com/devxoul/Cleverbot): Cleverbot for iOS using RxMVVM architecture
* [Drrrible](https://github.com/devxoul/Drrrible): Dribbble for iOS using RxMVVM architecture

## License

[Creative Commons Attribution 4.0 International license](http://creativecommons.org/licenses/by/4.0/)
