//
//  ObservableStateRegistrarTests.swift
//  ReactorKitSwiftUITests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import XCTest

import ReactorKitObservation

final class ObservableStateRegistrarTests: XCTestCase {

  // MARK: - testRegistrarHasUniqueID

  /// Verifies that a newly created registrar has a non-nil, unique ID.
  func testRegistrarHasUniqueID() {
    let registrar = ObservableStateRegistrar()
    let anotherRegistrar = ObservableStateRegistrar()
    XCTAssertNotEqual(registrar._$id, anotherRegistrar._$id)
  }

  // MARK: - testTwoRegistrarsHaveDifferentIDs

  /// Verifies that two independently created registrars always have different IDs.
  func testTwoRegistrarsHaveDifferentIDs() {
    let ids = (0..<100).map { _ in ObservableStateRegistrar()._$id }
    let uniqueIDs = Set(ids)
    XCTAssertEqual(uniqueIDs.count, ids.count, "All registrar IDs should be unique")
  }

  // MARK: - testCopiedRegistrarSharesID

  /// Verifies that copying a registrar (value semantics) preserves the same ID.
  func testCopiedRegistrarSharesID() {
    let registrar = ObservableStateRegistrar()
    let copy = registrar
    XCTAssertEqual(registrar._$id, copy._$id, "Copied registrar should share the same ID")
  }

  // MARK: - testAccessDoesNotCrash

  /// Verifies that calling access() with a conforming type does not crash.
  func testAccessDoesNotCrash() {
    let state = TestObservableState()
    // Call access directly on a copy of the registrar to avoid exclusivity issues.
    let registrar = state._$observationRegistrar
    registrar.access(state, keyPath: \TestObservableState.count)
    // No crash means success.
  }

  // MARK: - testMutateDoesNotCrash

  /// Verifies that calling _$mutate() on a registrar does not crash.
  func testMutateDoesNotCrash() {
    let registrar = ObservableStateRegistrar()
    let state = TestObservableState()
    var value = 0
    registrar._$mutate(state, keyPath: \TestObservableState.count, &value, 42, _$isIdentityEqual) { _, _ in true }
    XCTAssertEqual(value, 42)
    // Placeholder mutate does not crash.
  }
}

// MARK: - ObservableStateID Tests

final class ObservableStateIDTests: XCTestCase {

  // MARK: - testEqualityForSameID

  /// Verifies that the same ID instance is equal to itself.
  func testEqualityForSameID() {
    let id = ObservableStateID()
    XCTAssertEqual(id, id)
  }

  // MARK: - testInequalityForDifferentIDs

  /// Verifies that two different IDs are not equal.
  func testInequalityForDifferentIDs() {
    let id1 = ObservableStateID()
    let id2 = ObservableStateID()
    XCTAssertNotEqual(id1, id2)
  }

  // MARK: - testHashConsistency

  /// Verifies that equal IDs produce the same hash value.
  func testHashConsistency() {
    let id = ObservableStateID()
    let copy = id
    XCTAssertEqual(id.hashValue, copy.hashValue)
  }

  // MARK: - testUsableAsSetElement

  /// Verifies that ObservableStateID can be used as a Set element.
  func testUsableAsSetElement() {
    let id1 = ObservableStateID()
    let id2 = ObservableStateID()
    let id3 = ObservableStateID()

    var set: Set<ObservableStateID> = [id1, id2, id3]
    XCTAssertEqual(set.count, 3)

    // Re-inserting the same ID should not increase count.
    set.insert(id1)
    XCTAssertEqual(set.count, 3)
  }

  // MARK: - testUsableAsDictionaryKey

  /// Verifies that ObservableStateID can be used as a Dictionary key.
  func testUsableAsDictionaryKey() {
    let id1 = ObservableStateID()
    let id2 = ObservableStateID()

    var dict = [ObservableStateID: String]()
    dict[id1] = "first"
    dict[id2] = "second"

    XCTAssertEqual(dict[id1], "first")
    XCTAssertEqual(dict[id2], "second")
  }
}

// MARK: - Test Helper

/// A minimal manual conformance to ObservableState for testing purposes.
/// Avoids calling `mutate(&self, ...)` in the protocol method to prevent
/// overlapping exclusive access errors with value-type self.
struct TestObservableState: ObservableState {
  var _$observationRegistrar = ObservableStateRegistrar()

  var count = 0

  private func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool { true }
  private func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool { lhs != rhs }
  private func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool { lhs !== rhs }
  private func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool { lhs != rhs }

  mutating func _$willModify() {
    _$observationRegistrar._$willModify()
  }
}
