//
//  ObservableStateID.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Foundation

/// Identity tracking for struct state values.
///
/// Helps detect when the entire state is replaced vs individual properties changed.
/// Each state instance starts with a unique ID; copies share the same ID until
/// a full replacement occurs.
///
/// Uses Copy-on-Write semantics so that state copies share identity cheaply
/// via pointer comparison, and `_$willModify()` regenerates the UUID only when needed.
@frozen
public struct ObservableStateID: Hashable, Sendable {
  @usableFromInline
  final class Storage: @unchecked Sendable {
    var location: UUID

    init() {
      location = UUID()
    }

    init(location: UUID) {
      self.location = location
    }
  }

  @usableFromInline
  private(set) var storage: Storage

  public init() {
    storage = Storage()
  }

  /// Regenerates the identity. Called by `_$willModify()` to signal
  /// that this value is about to be mutated in-place.
  public mutating func _$willModify() {
    if isKnownUniquelyReferenced(&storage) {
      storage.location = UUID()
    } else {
      storage = Storage()
    }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.storage === rhs.storage || lhs.storage.location == rhs.storage.location
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(storage.location)
  }
}
