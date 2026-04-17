//
//  ManualObservedObject.swift
//  SwiftUICounter
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Combine

/// An `ObservableObject` that does NOT automatically trigger SwiftUI `body` updates.
///
/// SwiftUI's `@State` triggers `body` recomputation on every write. When updating state
/// inside `body` (e.g., for debugging counters), this causes infinite loops.
///
/// `ManualObservedObject` conforms to `ObservableObject` (for use with `@StateObject`)
/// but never sends `objectWillChange`. Instead, it provides a separate `valueWillChange`
/// publisher that subscribers can observe independently.
///
/// ```swift
/// @StateObject private var info = ManualObservedObject(ViewUpdateInfo())
///
/// var body: some View {
///   content
///     .background { let _ = info.value.computeCount += 1 }
///     .overlay {
///       SubscriptionReader(publisher: info.valueWillChange) { value in
///         Text("C:\(value.computeCount)")
///       }
///     }
/// }
/// ```
final class ManualObservedObject<Value>: ObservableObject {

  var value: Value {
    willSet { valueWillChangeSubject.send(newValue) }
  }

  let valueWillChange: AnyPublisher<Value, Never>

  private let valueWillChangeSubject = PassthroughSubject<Value, Never>()

  init(_ value: Value) {
    self.value = value
    self.valueWillChange = valueWillChangeSubject.eraseToAnyPublisher()
  }
}
