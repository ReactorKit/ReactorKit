//
//  InjectedReactorView.swift
//  ReactorKitSwiftUIExample
//
//  Created by Kanghoon Oh on 2025.
//  Copyright © 2025 ReactorKit. All rights reserved.
//

import SwiftUI

import ReactorKit

struct InjectedReactorView: SwiftUI.View {
  var body: some SwiftUI.View {
    ScrollView {
      VStack(spacing: 30) {
        VStack(spacing: 20) {
          Text("Independent Reactors")
            .font(.title2)
            .fontWeight(.bold)

          Text("Each child has its own reactor instance")
            .font(.caption)
            .foregroundColor(.secondary)

          HStack(spacing: 20) {
            ChildView(reactor: CounterReactor())
              .padding()
              .background(Color.blue.opacity(0.1))
              .cornerRadius(10)

            ChildView(reactor: CounterReactor())
              .padding()
              .background(Color.green.opacity(0.1))
              .cornerRadius(10)
          }
        }

        Divider()

        SharedReactorExample()
      }
      .padding()
    }
  }
}

struct ChildView: SwiftUI.View {
  @ObservedReactor var reactor: CounterReactor

  init(reactor: CounterReactor) {
    self._reactor = ObservedReactor(wrappedValue: reactor)
  }

  var body: some SwiftUI.View {
    VStack(spacing: 20) {
      Text("Child View")
        .font(.headline)

      Text("Count: \($reactor.state.value)")
        .font(.title2)
        .fontWeight(.bold)

      HStack(spacing: 20) {
        Button(action: { $reactor.send(.decrease) }) {
          Image(systemName: "minus.circle")
            .font(.title)
        }
        .disabled($reactor.value <= -10)

        Button(action: { $reactor.send(.reset) }) {
          Image(systemName: "arrow.counterclockwise.circle")
            .font(.title)
        }

        Button(action: { $reactor.send(.increase) }) {
          Image(systemName: "plus.circle")
            .font(.title)
        }
        .disabled($reactor.value >= 10)
      }

      VStack(alignment: .leading, spacing: 5) {
        Text("Access patterns:")
          .font(.caption)
          .fontWeight(.semibold)

        Group {
          Text("• $reactor.state.value: \($reactor.state.value)")
          Text("• $reactor.value: \($reactor.value)")
          Text("• $reactor(.action) - function call")
          Text("• $reactor.send(.action) - explicit")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
      }
    }
  }
}

struct SharedReactorExample: SwiftUI.View {
  @ObservedReactor var sharedReactor = CounterReactor()

  var body: some SwiftUI.View {
    VStack(spacing: 20) {
      Text("Shared Reactor Example")
        .font(.title)
        .fontWeight(.bold)

      Text("Multiple views share the same reactor")
        .font(.subheadline)
        .foregroundColor(.secondary)

      HStack(spacing: 20) {
        SharedChildView(reactor: sharedReactor)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.orange.opacity(0.1))
          .cornerRadius(10)

        SharedChildView(reactor: sharedReactor)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.purple.opacity(0.1))
          .cornerRadius(10)
      }

      Text("Changes in one view affect the other")
        .font(.caption)
        .foregroundColor(.secondary)

      Text("Parent control: \(sharedReactor.currentState.value)")
        .font(.caption2)
      Button("Parent Reset") {
        sharedReactor.action.onNext(.reset)
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }
}

private struct SharedChildView: SwiftUI.View {
  @ObservedReactor var reactor: CounterReactor

  init(reactor: CounterReactor) {
    self._reactor = ObservedReactor(wrappedValue: reactor)
  }

  var body: some SwiftUI.View {
    VStack(spacing: 10) {
      Text("\($reactor.value)")
        .font(.title)
        .fontWeight(.bold)

      HStack {
        Button("-") { $reactor.send(.decrease) }
        Button("Reset") { $reactor.send(.reset) }
        Button("+") { $reactor.send(.increase) }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }
}
