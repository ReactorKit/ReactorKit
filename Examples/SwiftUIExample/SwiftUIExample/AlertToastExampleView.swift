//
//  AlertToastExampleView.swift
//  SwiftUIExample
//
//  Shows how to handle alerts, toasts, and dialogs with ReactorKit in SwiftUI
//

import ReactorKit
import SwiftUI

// MARK: - Reactor

final class NotificationReactor: Reactor {
  enum Action {
    case showSuccess(String)
    case showError(String)
    case showConfirmDialog(title: String, message: String)
    case confirmAction
    case cancelAction
    case dismissNotification
  }

  enum Mutation {
    case setSuccessMessage(String?)
    case setErrorMessage(String?)
    case setDialog(DialogInfo?)
    case setIsProcessing(Bool)
    case setLastAction(String?)
  }

  struct State {
    var successMessage: String?
    var errorMessage: String?
    var dialogInfo: DialogInfo?
    var isProcessing = false
    var lastAction: String?
  }

  struct DialogInfo: Equatable {
    let title: String
    let message: String
  }

  let initialState = State()

  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .showSuccess(let message):
      .just(.setSuccessMessage(message))

    case .showError(let message):
      .just(.setErrorMessage(message))

    case .showConfirmDialog(let title, let message):
      .just(.setDialog(DialogInfo(title: title, message: message)))

    case .confirmAction:
      Observable.concat([
        .just(.setIsProcessing(true)),
        .just(.setDialog(nil)),
        Observable.just(.setLastAction("Confirmed"))
          .delay(.milliseconds(500), scheduler: MainScheduler.instance),
        .just(.setIsProcessing(false)),
      ])

    case .cancelAction:
      Observable.concat([
        .just(.setDialog(nil)),
        .just(.setLastAction("Cancelled")),
      ])

    case .dismissNotification:
      Observable.concat([
        .just(.setSuccessMessage(nil)),
        .just(.setErrorMessage(nil)),
      ])
    }
  }

  func reduce(state: State, mutation: Mutation) -> State {
    var newState = state

    switch mutation {
    case .setSuccessMessage(let message):
      newState.successMessage = message

    case .setErrorMessage(let message):
      newState.errorMessage = message

    case .setDialog(let info):
      newState.dialogInfo = info

    case .setIsProcessing(let processing):
      newState.isProcessing = processing

    case .setLastAction(let action):
      newState.lastAction = action
    }

    return newState
  }
}

// MARK: - View

struct AlertToastExampleView: SwiftUI.View {
  @ObservedReactor var reactor = NotificationReactor()

  var body: some SwiftUI.View {
    VStack(spacing: 30) {
      Text("Alert & Toast Examples")
        .font(.largeTitle)
        .fontWeight(.bold)

      // MARK: Trigger Buttons
      VStack(spacing: 15) {
        Button("Show Success Toast") {
          $reactor.send(.showSuccess("Operation completed!"))
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)

        Button("Show Error Alert") {
          $reactor.send(.showError("Something went wrong"))
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)

        Button("Show Confirm Dialog") {
          $reactor.send(.showConfirmDialog(
            title: "Confirm Action",
            message: "Are you sure you want to proceed?",
          ))
        }
        .buttonStyle(.borderedProminent)
      }

      // MARK: Status Display
      VStack(alignment: .leading, spacing: 10) {
        if $reactor.state.isProcessing {
          HStack {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
            Text("Processing...")
          }
        }

        if let lastAction = $reactor.state.lastAction {
          Text("Last action: \(lastAction)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)

      Spacer()
    }
    .padding()
    // MARK: Alert
    .alert("Error", isPresented: .constant($reactor.state.errorMessage != nil)) {
      Button("OK") {
        $reactor.send(.dismissNotification)
      }
    } message: {
      Text($reactor.state.errorMessage ?? "An error occurred")
    }
    // MARK: Confirmation Dialog
    .confirmationDialog(
      $reactor.state.dialogInfo?.title ?? "",
      isPresented: .constant($reactor.state.dialogInfo != nil),
      titleVisibility: .visible,
    ) {
      Button("Confirm") {
        $reactor.send(.confirmAction)
      }
      Button("Cancel", role: .cancel) {
        $reactor.send(.cancelAction)
      }
    } message: {
      Text($reactor.state.dialogInfo?.message ?? "")
    }
    // MARK: Toast Overlay
    .overlay(alignment: .top) {
      if let message = $reactor.state.successMessage {
        ToastView(message: message) {
          $reactor.send(.dismissNotification)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: $reactor.state.successMessage)
      }
    }
  }
}

// MARK: - Toast View Component

struct ToastView: SwiftUI.View {
  let message: String
  let onDismiss: () -> Void

  var body: some SwiftUI.View {
    Text(message)
      .padding()
      .background(Color.green.opacity(0.9))
      .foregroundColor(.white)
      .cornerRadius(10)
      .shadow(radius: 5)
      .padding(.top, 50)
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          onDismiss()
        }
      }
      .onTapGesture {
        onDismiss()
      }
  }
}

