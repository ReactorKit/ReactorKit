//
//  ViewController.swift
//  GitHubSearch
//
//  Created by Suyeol Jeon on 12/05/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import SafariServices
import UIKit

import ReactorKit
import RxCocoa
import RxSwift

class GitHubSearchViewController: UIViewController, StoryboardView {
  @IBOutlet var tableView: UITableView!
  let searchController = UISearchController(searchResultsController: nil)

  var disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.scrollIndicatorInsets.top = tableView.contentInset.top
    searchController.dimsBackgroundDuringPresentation = false
    navigationItem.searchController = searchController
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    UIView.setAnimationsEnabled(false)
    searchController.isActive = true
    searchController.isActive = false
    UIView.setAnimationsEnabled(true)
  }

  func bind(reactor: GitHubSearchViewReactor) {
    // Action
    searchController.searchBar.rx.text
      .throttle(0.3, scheduler: MainScheduler.instance)
      .map { Reactor.Action.updateQuery($0) }
      .bind(to: reactor.action)
      .disposed(by: disposeBag)

    tableView.rx.contentOffset
      .filter { [weak self] offset in
        guard let `self` = self else { return false }
        guard self.tableView.frame.height > 0 else { return false }
        return offset.y + self.tableView.frame.height >= self.tableView.contentSize.height - 100
      }
      .map { _ in Reactor.Action.loadNextPage }
      .bind(to: reactor.action)
      .disposed(by: disposeBag)

    // State
    reactor.state.map { $0.repos }
      .bind(to: tableView.rx.items(cellIdentifier: "cell")) { indexPath, repo, cell in
        cell.textLabel?.text = repo
      }
      .disposed(by: disposeBag)

    // View
    tableView.rx.itemSelected
      .subscribe(onNext: { [weak self, weak reactor] indexPath in
        guard let `self` = self else { return }
        self.view.endEditing(true)
        self.tableView.deselectRow(at: indexPath, animated: false)
        guard let repo = reactor?.currentState.repos[indexPath.row] else { return }
        guard let url = URL(string: "https://github.com/\(repo)") else { return }
        let viewController = SFSafariViewController(url: url)
        self.searchController.present(viewController, animated: true, completion: nil)
      })
      .disposed(by: disposeBag)
  }
}
