//
//  CounterView.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import SwiftUI

import ReactorKit
import ReactorKitSwiftUI

/// A counter view using `@ObservableState` + `@ReactorBindable` for two-way bindings.
struct CounterView: View {
  @ReactorBindable var reactor: ObservedReactor<CounterViewReactor>

  var body: some View {
    // ReactorObserving wires up the iOS 13–16 observation backport.
    // On iOS 17+ it is a transparent passthrough.
    ReactorObserving {
      content
    }
  }

  @ViewBuilder
  private var content: some View {
    Form {
      // MARK: - Counter
      Section("Counter") {
        Toggle("Show Counter", isOn: $reactor.isCounterVisible)
          ._highlightsOnUpdate()

        if reactor.isCounterVisible {
          HStack {
            Button { reactor.send(.decrease) } label: {
              Image(systemName: "minus.circle.fill")
            }
            .disabled(reactor.isLoading)

            Spacer()

            if reactor.isLoading {
              ProgressView()
            } else {
              Text("\(reactor.count)")
                .font(.system(.title, design: .monospaced))
            }

            Spacer()

            Button { reactor.send(.increase) } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(reactor.isLoading)
          }
          .buttonStyle(.borderless)
          .font(.title2)
          ._highlightsOnUpdate()
        }
      }

      // MARK: - Text Binding
      Section("Text Binding") {
        TextField("Type something...", text: $reactor.text)
          ._highlightsOnUpdate()
        if !reactor.text.isEmpty {
          Text("You typed: \(reactor.text)")
            .foregroundStyle(.secondary)
            ._highlightsOnUpdate()
        }
      }
    }
    .alert(
      reactor.alertMessage ?? "",
      isPresented: $reactor.showAlert
    ) {
      Button("OK", role: .cancel) {}
    }
  }
}

// MARK: - Preview

#Preview {
  CounterView(
    reactor: ObservedReactor(
      reactor: CounterViewReactor()
    )
  )
}
