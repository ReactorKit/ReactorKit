//
//  VanillaCounterModel.swift
//  SwiftUICounter
//
//  Vanilla SwiftUI + @Observable implementation for comparison with ReactorKit.
//

import Observation
import SwiftUI

@available(iOS 17.0, *)
@Observable
@MainActor
final class VanillaCounterModel {
  var count: Int = 0
  var text: String = ""
  var isCounterVisible: Bool = true
  var isLoading: Bool = false
  var showAlert: Bool = false
  var alertMessage: String?

  func increase() {
    guard !isLoading else { return }
    isLoading = true
    Task {
      do {
        try await Task.sleep(for: .milliseconds(300))
        count += 1
        alertMessage = "Count: \(count)"
        showAlert = true
      } catch {
        // Task cancelled — skip state update.
      }
      isLoading = false
    }
  }

  func decrease() {
    guard !isLoading else { return }
    isLoading = true
    Task {
      do {
        try await Task.sleep(for: .milliseconds(300))
        count -= 1
        alertMessage = "Count: \(count)"
        showAlert = true
      } catch {
        // Task cancelled — skip state update.
      }
      isLoading = false
    }
  }

  func toggleCounterVisible() {
    isCounterVisible.toggle()
  }
}
