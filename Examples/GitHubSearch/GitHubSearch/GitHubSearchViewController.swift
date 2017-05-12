//
//  ViewController.swift
//  GitHubSearch
//
//  Created by Suyeol Jeon on 12/05/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import UIKit

class GitHubSearchViewController: UIViewController {
  @IBOutlet var searchBar: UISearchBar!
  @IBOutlet var tableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.contentInset.top = 44 // search bar height
    tableView.scrollIndicatorInsets.top = tableView.contentInset.top

    // If you're using Storyboard, it's recommended to set a reactor after the view is loaded.
    // `bind(reactor:)` gets called each time the reactor is assigned.
    self.reactor = GitHubSearchViewReactor()
  }

  func bind(reactor: GitHubSearchViewReactor) {
    // Action
    searchBar.rx.text
      .throttle(0.3, scheduler: MainScheduler.instance)
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
}
