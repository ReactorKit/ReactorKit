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
  @State private var reactor = ObservedReactor(reactor: CounterViewReactor())

  var body: some Scene {
    WindowGroup {
      TabView {
        CounterView(reactor: reactor)
          .tabItem { Label("ReactorKit", systemImage: "atom") }

        if #available(iOS 17.0, *) {
          VanillaTab()
            .tabItem { Label("Vanilla", systemImage: "swift") }
        }
      }
    }
  }
}

@available(iOS 17.0, *)
private struct VanillaTab: View {
  @State private var model = VanillaCounterModel()

  var body: some View {
    VanillaCounterView(model: model)
  }
}
