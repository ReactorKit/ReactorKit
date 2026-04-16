//
//  ObservableStateMacroCompilationTests.swift
//  ReactorKitObservationTests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import XCTest

import ReactorKitObservation

// MARK: - Test Fixtures

/// 1a. Basic multi-property state — type-inferred bindings
@ObservableState
private struct BasicState {
  var count = 0
  var name = ""
  var isLoading = false
}

/// 1b. Same shape with explicit type annotations.
/// Verifies the peer-cloning backing-storage path works regardless of
/// whether the user wrote a type annotation.
@ObservableState
private struct TypedBasicState {
  var count: Int = 0
  var name: String = ""
  var isLoading: Bool = false
}

/// 1c. Mixed: some properties typed, some inferred.
@ObservableState
private struct MixedAnnotationState {
  var count: Int = 0
  var name = ""
  var ratio: Double = 1.0
  var isReady = false
}

/// 2. State with @ObservableStateIgnored
@ObservableState
private struct IgnoredPropertyState {
  var tracked = 0
  @ObservableStateIgnored
  var ignored = 0
}

/// 3. Optional properties
@ObservableState
private struct OptionalState {
  var title: String? = nil
  var count = 0
}

/// 4. Property-wrapper coexistence via explicit `@ObservableStateIgnored`.
///
/// `@ObservableState` only auto-skips property wrappers listed in the
/// macro's `knownSupportedPropertyWrappers` whitelist (currently just
/// `@Pulse`). Any other wrapper — including this local `@TestWrapper`
/// stub and arbitrary user-defined wrappers — must be explicitly marked
/// with `@ObservableStateIgnored`, matching Apple's native `@Observable`
/// convention. Without the marker, the macro would try to synthesize
/// its own accessors alongside the wrapper's, producing a compile error.
///
/// Uses a local stub instead of ReactorKit's `@Pulse` so this target
/// stays independent of ReactorKit.
@propertyWrapper
private struct TestWrapper<Value> {
  var wrappedValue: Value
}

@ObservableState
private struct PulseState {
  var count = 0
  @ObservableStateIgnored
  @TestWrapper var alertMessage: String? = nil
}

/// 5. Nested @ObservableState
@ObservableState
private struct InnerState {
  var value = 0
}

@ObservableState
private struct OuterState {
  var inner = InnerState()
  var label = ""
}

/// 6. Edge cases
@ObservableState
private struct EmptyState {}

@ObservableState
private struct LetOnlyState {
  let id = 0
}

/// 7. Container-typed properties — exercises the `_modify` accessor
/// on collection members where we deliberately skip post-mutation
/// Equatable comparison to preserve copy-on-write O(1) semantics.
@ObservableState
private struct ContainerState {
  var items: [Int] = []
  var lookup: [String: Int] = [:]
  var count: Int = 0
}

/// 8. Public state — regression guard: the macro must propagate the
/// enclosing type's access level to `_$observationRegistrar` and
/// `_$willModify()` so a `public struct` can satisfy the public
/// `ObservableState` protocol's requirements.
@ObservableState
public struct PublicObservableStateFixture {
  public var count: Int = 0
  public var name: String = ""
  public init() {}
}

// MARK: - Tests

final class ObservableStateMacroCompilationTests: XCTestCase {

  // P0: Conformance added by extension macro
  func testMacroGeneratesObservableStateConformance() {
    let _: any ObservableState.Type = BasicState.self
  }

  // P0: All properties read/write — compile success = Bug 1,2 fixed
  func testMacroGeneratedStructCompiles() {
    var state = BasicState()
    state.count = 42
    state.name = "hello"
    state.isLoading = true
    XCTAssertEqual(state.count, 42)
    XCTAssertEqual(state.name, "hello")
    XCTAssertTrue(state.isLoading)
  }

  // P0: Registrar exists
  func testMacroGeneratedStructHasRegistrar() {
    let state = BasicState()
    let _: ObservableStateRegistrar = state._$observationRegistrar
  }

  // P0: Setter tracks mutations
  func testMacroGeneratedStructTracksMutations() {
    var state = BasicState()
    state.count = 1
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\BasicState.count))
    XCTAssertFalse(state._$observationRegistrar._$mutatedKeyPaths.contains(\BasicState.name))
  }

  // P0: Type-annotated bindings — peer-clone path preserves explicit types
  func testTypedBasicStateCompilesAndTracks() {
    var state = TypedBasicState()
    state.count = 7
    state.name = "typed"
    state.isLoading = true
    XCTAssertEqual(state.count, 7)
    XCTAssertEqual(state.name, "typed")
    XCTAssertTrue(state.isLoading)
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\TypedBasicState.count))
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\TypedBasicState.name))
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\TypedBasicState.isLoading))
  }

  // P0: Mixed annotated / inferred properties in the same struct
  func testMixedAnnotationStateCompilesAndTracks() {
    var state = MixedAnnotationState()
    state.count = 3
    state.name = "mixed"
    state.ratio = 2.5
    state.isReady = true
    XCTAssertEqual(state.count, 3)
    XCTAssertEqual(state.name, "mixed")
    XCTAssertEqual(state.ratio, 2.5)
    XCTAssertTrue(state.isReady)
    let mutated = state._$observationRegistrar._$mutatedKeyPaths
    XCTAssertTrue(mutated.contains(\MixedAnnotationState.count))
    XCTAssertTrue(mutated.contains(\MixedAnnotationState.name))
    XCTAssertTrue(mutated.contains(\MixedAnnotationState.ratio))
    XCTAssertTrue(mutated.contains(\MixedAnnotationState.isReady))
  }

  // P0: property-wrapper coexistence — compile success = Bug 3 fixed
  func testPropertyWrapperCoexistsWithMacro() {
    var state = PulseState()
    state.count = 1
    _ = state.alertMessage
    XCTAssertEqual(state.count, 1)
  }

  // P1: Ignored property not tracked
  func testIgnoredPropertyDoesNotTrackMutation() {
    var state = IgnoredPropertyState()
    state.ignored = 99
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.isEmpty)
    state.tracked = 1
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\IgnoredPropertyState.tracked))
  }

  // P1: Optional property tracking
  func testOptionalPropertyTracking() {
    var state = OptionalState()
    state.title = "hello"
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\OptionalState.title))
  }

  // P1: Nested struct tracking
  func testNestedObservableStateTracking() {
    var state = OuterState()
    state.inner = InnerState(value: 42)
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\OuterState.inner))
  }

  // P2: Empty struct
  func testEmptyStructConformsToObservableState() {
    let _: any ObservableState.Type = EmptyState.self
  }

  // P2: Let-only struct
  func testLetOnlyStructConformsToObservableState() {
    let _: any ObservableState.Type = LetOnlyState.self
  }

  // MARK: - `_modify` accessor behavior

  // P0: compound scalar assignment goes through `_modify` and is tracked
  func testCompoundScalarMutationGoesThroughModify() {
    var state = ContainerState()
    state.count += 1
    XCTAssertEqual(state.count, 1)
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\ContainerState.count))
  }

  // P0: in-place array mutation goes through `_modify` and is tracked.
  //
  // This is the container-shaped case that drives our "no post-mutation
  // Equatable check" policy: adding such a check would force a pre-yield
  // copy of the array, breaking the copy-on-write fast path and turning
  // an O(1) `append` into O(N). The `_modify bookends` MARK section in
  // `ObservableStateRegistrar` explains the trade-off.
  func testInPlaceArrayAppendGoesThroughModify() {
    var state = ContainerState()
    state.items.append(1)
    state.items.append(2)
    state.items.append(3)
    XCTAssertEqual(state.items, [1, 2, 3])
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\ContainerState.items))
  }

  // P0: in-place dictionary subscript mutation goes through `_modify`
  // and is tracked.
  func testInPlaceDictionaryMutationGoesThroughModify() {
    var state = ContainerState()
    state.lookup["a"] = 1
    state.lookup["b"] = 2
    XCTAssertEqual(state.lookup, ["a": 1, "b": 2])
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\ContainerState.lookup))
  }

  // P1: `_modify` intentionally over-fires.
  //
  // A no-op compound mutation like `count += 0` still drives the full
  // `_modify` → `willModify` / `didModify` bookend pair, so the key
  // path is recorded in `_$mutatedKeyPaths` even though the new value
  // equals the old. We prefer this over a post-mutation Equatable
  // check that would force CoW copies on container-shaped members.
  // SwiftUI's downstream view-body diffing is expected to absorb the
  // redundant re-render cheaply for the rare no-op case. If this test
  // ever starts failing, someone added a pre/post compare somewhere
  // on the hot path — revisit the performance trade-off before
  // "fixing" it.
  func testModifyOverFiresForNoOpScalarMutation() {
    var state = ContainerState()
    state.count += 0
    XCTAssertTrue(state._$observationRegistrar._$mutatedKeyPaths.contains(\ContainerState.count))
  }

  // MARK: - Nested `ObservableState` identity bumping

  // P0: in-place mutation of a nested `ObservableState` member routes
  // through the parent's `_modify` accessor, which calls the
  // `willModify<Member: ObservableState>` overload. That overload
  // bumps the nested state's `_$id` via `member._$willModify()`, and
  // the parent's `didModify` records the parent keyPath in
  // `_$mutatedKeyPaths`. This test guards both halves: the nested
  // identity bumping AND the parent-level keyPath tracking.
  func testNestedInPlaceMutationBumpsIdentityAndTracksParentKeyPath() {
    var state = OuterState()
    let originalInnerID = state.inner._$observationRegistrar._$id

    state.inner.value += 1

    XCTAssertEqual(state.inner.value, 1)
    XCTAssertTrue(
      state._$observationRegistrar._$mutatedKeyPaths.contains(\OuterState.inner),
      "Parent `_$mutatedKeyPaths` must include the nested key path after in-place mutation"
    )
    XCTAssertNotEqual(
      state.inner._$observationRegistrar._$id,
      originalInnerID,
      "Nested state's `_$id` must be bumped by the parent's `willModify` overload"
    )
  }

  // MARK: - Public state conformance

  // P0: regression guard for access-level propagation. A `public
  // struct` conforming to the public `ObservableState` protocol must
  // have `public` witnesses for `_$observationRegistrar` and
  // `_$willModify()`. If the macro stops propagating access level,
  // this file fails to compile with: "property '_$observationRegistrar'
  // must be declared public because it matches a requirement in
  // public protocol 'ObservableState'".
  func testPublicStructConformsToPublicProtocol() {
    var state = PublicObservableStateFixture()
    state.count = 42
    XCTAssertEqual(state.count, 42)
    let _: any ObservableState.Type = PublicObservableStateFixture.self
  }
}
