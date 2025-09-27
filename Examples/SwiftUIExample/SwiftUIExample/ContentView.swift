//
//  ContentView.swift
//  ReactorKitSwiftUIExample
//
//  Created by Kanghoon Oh on 2025.
//  Copyright © 2025 ReactorKit. All rights reserved.
//

import SwiftUI

import ReactorKit

struct ContentView: SwiftUI.View {
  var body: some SwiftUI.View {
    TabView {
      BasicCounterView()
        .tabItem {
          Label("Basic", systemImage: "1.circle")
        }

      BindingExamplesView()
        .tabItem {
          Label("Bindings", systemImage: "link")
        }

      AlertToastExampleView()
        .tabItem {
          Label("Alerts", systemImage: "bell")
        }

      InjectedReactorView()
        .tabItem {
          Label("Injected", systemImage: "arrow.down.circle")
        }
    }
  }
}
