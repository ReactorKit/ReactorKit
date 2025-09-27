//
//  BindingExamplesView.swift
//  ReactorKitSwiftUIExample
//
//  Created by Kanghoon Oh on 2025.
//  Copyright © 2025 ReactorKit. All rights reserved.
//

import SwiftUI

import ReactorKit

struct BindingExamplesView: SwiftUI.View {
  @ObservedReactor var reactor = CounterReactor()

  var body: some SwiftUI.View {
    ScrollView {
      VStack(spacing: 30) {
        Text("Binding Examples")
          .font(.largeTitle)
          .fontWeight(.bold)

        // MARK: 1. Basic Binding with KeyPath
        GroupBox(label: Label("1. TextField Binding (KeyPath)", systemImage: "text.cursor")) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Use binding with KeyPath to connect UI controls to state")
              .font(.caption)
              .foregroundColor(.secondary)

            TextField(
              "Enter text",
              text: $reactor.binding(
                \.text, // KeyPath to state property
                send: { CounterReactor.Action.setText($0) }, // Convert to Action
              ),
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())

            Text("Current text: \($reactor.state.text)")
              .font(.caption)
          }
          .padding(.vertical, 5)
        }

        // MARK: 2. Custom Binding with Get/Set
        GroupBox(label: Label("2. Custom Binding (Get/Set)", systemImage: "slider.horizontal.3")) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Use custom get/set closures for complex bindings")
              .font(.caption)
              .foregroundColor(.secondary)

            Slider(
              value: .constant(Double($reactor.state.value)),
              in: -10...10,
              step: 1,
            )
            .disabled(true)

            Text("Slider value: \(Int($reactor.state.value))")
              .font(.caption)
          }
          .padding(.vertical, 5)
        }

        // MARK: 3. Toggle Binding
        GroupBox(label: Label("3. Toggle Binding", systemImage: "switch.2")) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Binding boolean state to Toggle")
              .font(.caption)
              .foregroundColor(.secondary)

            Toggle("Loading State", isOn: $reactor.binding(
              \.isLoading,
              send: { CounterReactor.Action.setLoading($0) },
            ))
            .toggleStyle(SwitchToggleStyle())

            if $reactor.state.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
            }
          }
          .padding(.vertical, 5)
        }

        // MARK: 4. Read-only Binding
        GroupBox(label: Label("4. Read-only State Access", systemImage: "eye")) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Direct state access without binding")
              .font(.caption)
              .foregroundColor(.secondary)

            HStack {
              Text("Counter:")
              Text("\($reactor.state.value)")
                .font(.title2)
                .fontWeight(.bold)
            }

            HStack {
              Text("Text:")
              Text($reactor.state.text.isEmpty ? "Empty" : $reactor.state.text)
                .font(.title3)
            }

            HStack {
              Text("Loading:")
              Image(systemName: $reactor.state.isLoading ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor($reactor.state.isLoading ? .green : .red)
            }
          }
          .padding(.vertical, 5)
        }

        // MARK: 5. Dynamic Member Lookup
        GroupBox(label: Label("5. Dynamic Member Lookup", systemImage: "arrow.right.circle")) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Access state properties directly via $reactor")
              .font(.caption)
              .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 5) {
              Text("$reactor.value = \($reactor.value)")
              Text("$reactor.text = \"\($reactor.text)\"")
              Text("$reactor.isLoading = \($reactor.isLoading)")
            }
            .font(.system(.body, design: .monospaced))
          }
          .padding(.vertical, 5)
        }
      }
      .padding()
    }
    .navigationTitle("Bindings")
  }
}
