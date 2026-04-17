//
//  MacroDeclarations.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

#if canImport(Observation)
@_exported import Observation
#endif

/// Instruments a struct for per-property observation tracking.
///
/// Apply this macro to a `State` struct inside a `Reactor` to enable fine-grained
/// SwiftUI observation. The macro synthesizes:
/// - An ``ObservableStateRegistrar`` stored property (`_$observationRegistrar`)
/// - `shouldNotifyObservers` overloads for Equatable-based mutation skip
/// - Per-property accessor wrappers (via ``ObservableStateTracked()``) that call through to the registrar
///
/// ```swift
/// @ObservableState
/// struct State {
///   var count: Int = 0
///   var name: String = ""
/// }
/// ```
@attached(
  member,
  names: named(_$observationRegistrar),
  named(_$willModify),
  named(shouldNotifyObservers)
)
@attached(memberAttribute)
@attached(extension, conformances: ObservableState, Observation.Observable)
public macro ObservableState() = #externalMacro(module: "ReactorKitMacros", type: "ObservableStateMacro")

/// Attached to individual stored properties by ``ObservableState()`` via its
/// `memberAttribute` role. Generates:
/// - accessor wrappers (`init`/`get`/`set`/`_modify`) that delegate to backing storage
/// - a `_`-prefixed peer backing-storage declaration marked with
///   `@ObservableStateIgnored` so the compiler does not re-instrument it
///
/// You do not use this macro directly — it is applied automatically.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateTracked() = #externalMacro(module: "ReactorKitMacros", type: "ObservableStateTrackedMacro")

/// Marks a stored property to be excluded from observation tracking.
///
/// Properties annotated with `@ObservableStateIgnored` will not trigger
/// view re-renders when their value changes.
///
/// ```swift
/// @ObservableState
/// struct State {
///   var count: Int = 0             // tracked
///   @ObservableStateIgnored
///   var internalCache: [String] = []  // not tracked
/// }
/// ```
///
/// Declared as an `accessor` macro (returning no accessors) so that applying
/// it to a property preserves the property's stored-property semantics. The
/// compiler sees the attribute as a no-op rather than stripping accessors.
@attached(accessor, names: named(willSet))
public macro ObservableStateIgnored() = #externalMacro(module: "ReactorKitMacros", type: "ObservableStateIgnoredMacro")
