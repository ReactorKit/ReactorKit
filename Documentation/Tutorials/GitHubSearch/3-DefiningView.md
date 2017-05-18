# Defining View

Now we have a working reactor. In this chapter we'll bind the reactor to a view. In ReactorKit, normal views, cells and view controllers are treated as a view. ReactorKit has a protocol named `View` for views.

A protocol `View` requires a dispose bag property and a binding method. This is a basic implementation of a `View`.

**GitHubSearchViewController.swift**

```swift
import UIKit
import ReactorKit
import RxSwift

class GitHubSearchViewController: UIViewController, View {
  var disposeBag = DisposeBag()

  func bind(reactor: GitHubSearchViewReactor) {
    // define action and state bindings here
  }
}
```

A view will automatically have a property `reactor` if the view conforms to the protocol `View`. The method `bind()` is called just after the new reactor is assigned. You can assign a new reactor anywhere but if you're using storyboard it's recommended to do it after the `super.viewDidLoad()`.

```swift
override func viewDidLoad() {
  super.viewDidLoad()
  reactor = GitHubSearchViewReactor() // this makes `bind()` get called
}
```

Define action and state bindings in `bind()`. Thanks to RxCocoa you can easily bind UI elements with action and state.

```swift
func bind(reactor: GitHubSearchViewReactor) {
  // Action
  searchBar.rx.text
    .map { Reactor.Action.updateQuery($0) }
    .bind(to: reactor.action)
    .disposed(by: disposeBag)

  // State
  reactor.state.map { $0.repos }
    .bind(to: tableView.rx.items(cellIdentifier: "cell")) { indexPath, repo, cell in
      cell.textLabel?.text = repo
    }
    .disposed(by: disposeBag)
}
```
