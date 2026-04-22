//
//  ReactorObserving.swift
//  ReactorKitSwiftUI
//
//  Created by Kanghoon Oh on 4/11/26.
//

import SwiftUI

/// A SwiftUI view that enables observation tracking for ``ObservedReactor``.
///
/// On iOS 17+, this is a transparent passthrough — SwiftUI natively tracks property access
/// on `Observable` types, including per-property tracking for `@ObservableState`.
///
/// On iOS 13~16, it tracks which ``ObservedReactor`` properties are accessed during the
/// content closure, and triggers a re-render when those properties change.
///
/// ```swift
/// struct CounterView: View {
///   let reactor: ObservedReactor<CounterViewReactor>
///
///   var body: some View {
///     ReactorObserving {
///       Text("\(reactor.count)")
///       Button("+") { reactor.send(.increase) }
///     }
///   }
/// }
/// ```
/// Configuration for ``ReactorObserving`` runtime diagnostics.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
public enum ReactorObservingConfiguration {
  /// Controls whether a runtime warning is emitted in DEBUG builds when
  /// ``ObservedReactor`` state is accessed outside of ``ReactorObserving``.
  ///
  /// Set to `false` if your minimum deployment target is iOS 17+ and you
  /// don't need backward-compatible state tracking.
  ///
  /// ```swift
  /// ReactorObservingConfiguration.isTrackingCheckEnabled = false
  /// ```
  public static var isTrackingCheckEnabled = true
}

/// ``ReactorObserving`` is a **type-transparent wrapper**: its `body`
/// returns `Content` directly rather than `some View`, so SwiftUI does
/// not interpose an extra wrapper node in the view hierarchy. This
/// avoids the stale-first-render problem where an intermediate wrapper
/// view causes bound child views (e.g. a `TextField` inside
/// `_highlightsOnUpdate()`) to re-evaluate once on the first parent
/// mutation before SwiftUI's identity diffing kicks in.
///
/// - On iOS 17+: `body` is a DEBUG-only task-local wrapper around
///   `content()`. Native Observation handles all per-property tracking,
///   so there is nothing else for this view to do.
/// - On iOS 13–16: `body` runs the content inside `withStateTracking`,
///   which records per-property accesses on the backport registrar and
///   reschedules the body via a `@State` tick when any tracked property
///   mutates.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
public struct ReactorObserving<Content> {
  @State private var id: UInt = 0
  private let content: () -> Content

  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ReactorObserving: View where Content: View {
  public var body: Content {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
      // Native Observation handles per-property tracking automatically.
      // In DEBUG, we still flip `_ReactorLocals.isInReactorObserving`
      // on for the synchronous duration of `content()` so that
      // `@ReactorBindable`'s binding subscript can snapshot-and-restore
      // the flag across deferred binding reads (see the type-level doc
      // on `ReactorBindable`). In RELEASE, this is a plain passthrough.
      #if DEBUG
      return _ReactorLocals.$isInReactorObserving.withValue(true) { content() }
      #else
      return content()
      #endif
    } else {
      // Read @State to create a SwiftUI dependency — when `id` changes,
      // SwiftUI re-evaluates the surrounding body, restarting tracking.
      let _ = id
      // `MainActor.assumeIsolated` is safe here because:
      // - ObservedReactor is @MainActor and its init hops the reactor
      //   state stream onto MainScheduler before writing to `state`,
      //   so the setter always runs on the main thread regardless of
      //   where the Reactor pipeline emitted from.
      // - BackportRegistrar.willSet (which fires this callback) is
      //   called from that setter.
      // - Using async dispatch would defer the @State update, causing a
      //   frame of stale UI.
      return _ReactorLocals.$isInReactorObserving.withValue(true) {
        _withStateTracking(content, onChange: {
          MainActor.assumeIsolated { id &+= 1 }
        })
      }
    }
  }
}
