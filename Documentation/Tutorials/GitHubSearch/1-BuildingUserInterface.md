# Building User Interface

First you have to build a user interface. This tutorial premises that you have a basic knowledge of building user interface. GitHubSearch application has a single UISearchBar and an UITableView. User types the query to the search bar then the search results will be displayed in the table view.

![github-search](https://cloud.githubusercontent.com/assets/931655/26028397/76671e92-385a-11e7-972f-5005160eb690.png)

Here is the code of `GitHubSearchViewController`:

**GitHubSearchViewController.swift**

```swift
import UIKit

final class GitHubSearchViewController: UIViewController {
  @IBOutlet var searchBar: UISearchBar!
  @IBOutlet var tableView: UITableView!
}
```

Don't forget to add a prototype cell to the table view. In this tutorial the cell identifier of the property cell is `"cell"`.
