//
//  CounterApp.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import SwiftUI

import ReactorKitSwiftUI

@main
struct CounterApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        CounterView(
          reactor: ObservedReactor(reactor: CounterViewReactor())
        )
        .tabItem { Label("ReactorKit", systemImage: "atom") }

        if #available(iOS 17.0, *) {
          VanillaCounterView(model: VanillaCounterModel())
            .tabItem { Label("Vanilla", systemImage: "swift") }
        }
      }
    }
  }
}
