//
//  HighlightsOnUpdate.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Combine
import SwiftUI

extension View {

  /// In debug mode, overlays compute and draw counts when the view updates.
  ///
  /// - **C**: Number of times the view's `body` was computed.
  /// - **D**: Number of times the view was drawn on screen.
  ///
  /// > Tip:
  /// > Uses `#if DEBUG` internally, so no external compiler flag is needed.
  ///
  /// - Important: Returns `self` unchanged in release builds.
  func _highlightsOnUpdate() -> some View {
    #if DEBUG
    ViewUpdateHighlightedContent { self }
    #else
    self
    #endif
  }
}

// MARK: Private

/// Tracks how many times a view has been computed and drawn.
private struct ViewUpdateInfo: Hashable {
  var computeCount = 0
  var drawCount = 0
}

/// Wraps content to count body computations and draw calls.
///
/// Implemented as a `View` rather than a `ViewModifier` because `body(content:)` is not
/// re-invoked when the wrapped content's `body` is recomputed. By using `background(_:)`,
/// the compute count increments each time the content's body is evaluated.
///
/// The Canvas renderer callback fires when the view is actually drawn on screen.
/// Since the Canvas lives in `background` (not in the overlay), the overlay's
/// recomputation does NOT trigger another Canvas draw — no feedback loop.
private struct ViewUpdateHighlightedContent<Content: View>: View {

  @StateObject private var info = ManualObservedObject<ViewUpdateInfo>(.init())

  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .background {
        // Increment compute count on each body evaluation.
        // Uses an immediately-invoked closure to execute side effects in @ViewBuilder.
        let _ = info.value.computeCount += 1
        // Increment draw count when the view is actually rendered.
        // This fires at draw time, after body evaluation, giving an accurate count.
        Canvas { _, _ in info.value.drawCount += 1 }
      }
      .overlay {
        ViewUpdateHighlight(publisher: info.valueWillChange)
      }
  }
}

/// Displays a colored border and count labels when the view updates.
///
/// Accepts a publisher directly to keep a stable subscription across body evaluations.
private struct ViewUpdateHighlight: View {

  let publisher: AnyPublisher<ViewUpdateInfo, Never>
  @State private var highlightColor = Color.allSystemColors.randomElement() ?? .blue

  var body: some View {
    SubscriptionReader(
      publisher: publisher.map { value in
        Just<ViewUpdateInfo?>(value).append(
          Just(nil).delay(for: .seconds(0.5), scheduler: RunLoop.main)
        )
      }
      .switchToLatest()
    ) { info in
      if let info {
        Rectangle()
          .strokeBorder(highlightColor)
          .overlay(alignment: .topLeading) {
            Text("C:\(info.computeCount) D:\(info.drawCount)")
              .foregroundColor(.white)
              .padding(.horizontal, 2)
              .background(highlightColor)
              .font(.system(size: 8.0, weight: .regular, design: .monospaced))
              .fixedSize()
          }
      }
    }
  }
}

extension Color {
  fileprivate static var allSystemColors: [Self] {
    [
      .red, .orange, .yellow, .green, .mint, .teal,
      .cyan, .blue, .indigo, .purple, .pink, .brown,
    ]
  }
}
