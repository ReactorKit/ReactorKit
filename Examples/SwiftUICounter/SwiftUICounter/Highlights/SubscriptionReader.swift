//
//  SubscriptionReader.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Combine
import SwiftUI

/// A view that subscribes to a publisher and builds content from emitted values.
///
/// Each time the publisher emits, the output is stored in `@State` to trigger a view update.
/// Returns `EmptyView` until the publisher emits its first value.
struct SubscriptionReader<
  PublisherType: Publisher,
  Content: View
>: View where PublisherType.Failure == Never {

  private let publisher: PublisherType
  private let content: (PublisherType.Output) -> Content

  @State private var output: PublisherType.Output?

  init(
    publisher: PublisherType,
    @ViewBuilder content: @escaping (PublisherType.Output) -> Content
  ) {
    self.publisher = publisher
    self.content = content
  }

  var body: some View {
    SubscriptionView(
      content: Group {
        if let output {
          content(output)
        }
      },
      publisher: publisher,
      action: { output = $0 }
    )
  }
}
