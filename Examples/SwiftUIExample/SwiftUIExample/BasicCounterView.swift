//
//  BasicCounterView.swift
//  ReactorKitSwiftUIExample
//
//  Created by Kanghoon Oh on 2025.
//  Copyright © 2025 ReactorKit. All rights reserved.
//

import SwiftUI

import ReactorKit

struct BasicCounterView: SwiftUI.View {
  @ObservedReactor var reactor = CounterReactor()

  var body: some SwiftUI.View {
    VStack(spacing: 30) {
      Text("Basic Counter Example")
        .font(.largeTitle)
        .fontWeight(.bold)

      // Current value display
      Text("\($reactor.state.value)")
        .font(.system(size: 72, weight: .bold, design: .rounded))
        .foregroundColor(colorForValue($reactor.state.value))
        .animation(.easeInOut(duration: 0.2), value: $reactor.state.value)

      // Control buttons
      HStack(spacing: 20) {
        Button(action: { $reactor.send(.decrease) }) {
          Image(systemName: "minus.circle.fill")
            .font(.system(size: 44))
        }
        .disabled($reactor.state.value <= -10)

        Button(action: { $reactor.send(.reset) }) {
          Image(systemName: "arrow.counterclockwise.circle.fill")
            .font(.system(size: 44))
        }

        Button(action: { $reactor.send(.increase) }) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 44))
        }
        .disabled($reactor.state.value >= 10)
      }

      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 10)
            .cornerRadius(5)

          Rectangle()
            .fill(colorForValue($reactor.state.value))
            .frame(width: progressWidth(for: $reactor.state.value, in: geometry.size.width), height: 10)
            .cornerRadius(5)
            .animation(.spring(), value: $reactor.state.value)
        }
      }
      .frame(height: 10)
      .padding(.horizontal, 30)

      // State info using dynamic member lookup
      VStack(spacing: 10) {
        Text("Direct access via $reactor.value: \($reactor.value)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }

  private func colorForValue(_ value: Int) -> Color {
    switch value {
    case ..<0:
      .red
    case 0:
      .gray
    case 1...5:
      .blue
    default:
      .green
    }
  }

  private func progressWidth(for value: Int, in totalWidth: CGFloat) -> CGFloat {
    let normalizedValue = (CGFloat(value) + 10) / 20 // Normalize -10...10 to 0...1
    return max(0, min(totalWidth, normalizedValue * totalWidth))
  }
}
