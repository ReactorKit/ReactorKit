//
//  AppDelegate.swift
//  GitHubSearch
//
//  Created by Suyeol Jeon on 12/05/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    let navigationController = self.window?.rootViewController as! UINavigationController
    navigationController.navigationBar.prefersLargeTitles = true
    let viewController = navigationController.viewControllers.first as! GitHubSearchViewController
    viewController.reactor = GitHubSearchViewReactor()
    return true
  }
}
