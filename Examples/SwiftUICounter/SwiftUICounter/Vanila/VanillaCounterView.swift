//
//  VanillaCounterView.swift
//  SwiftUICounter
//
//  Vanilla SwiftUI + @Observable implementation for comparison with ReactorKit.
//

import SwiftUI

@available(iOS 17.0, *)
struct VanillaCounterView: View {
  @Bindable var model: VanillaCounterModel

  var body: some View {
    Form {
      // MARK: - Counter
      Section("Counter") {
        Toggle("Show Counter", isOn: $model.isCounterVisible)
        ._highlightsOnUpdate()

        if model.isCounterVisible {
          HStack {
            Button { model.decrease() } label: {
              Image(systemName: "minus.circle.fill")
            }
            .disabled(model.isLoading)

            Spacer()

            if model.isLoading {
              ProgressView()
            } else {
              Text("\(model.count)")
                .font(.system(.title, design: .monospaced))
            }

            Spacer()

            Button { model.increase() } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(model.isLoading)
          }
          .buttonStyle(.borderless)
          .font(.title2)
          ._highlightsOnUpdate()
        }
      }

      // MARK: - Text Binding
      Section("Text Binding") {
        TextField("Type something...", text: $model.text)
        ._highlightsOnUpdate()
        if !model.text.isEmpty {
          Text("You typed: \(model.text)")
            .foregroundStyle(.secondary)
            ._highlightsOnUpdate()
        }
      }
    }
    .alert(
      model.alertMessage ?? "",
      isPresented: $model.showAlert
    ) {
      Button("OK", role: .cancel) {}
    }
  }
}

@available(iOS 17.0, *)
#Preview {
  VanillaCounterView(model: VanillaCounterModel())
}
