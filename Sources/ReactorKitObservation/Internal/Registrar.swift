//
//  Registrar.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/11/26.
//

import Foundation
#if canImport(Observation)
import Observation
#endif

/// A unified observation registrar that always calls `BackportRegistrar` (for the iOS 13–16 observation
/// backport scope) and additionally delegates to native `ObservationRegistrar` on iOS 17+
/// (for SwiftUI native observation).
public struct _ReactorRegistrar: @unchecked Sendable {
  private let backport = BackportRegistrar()
  private let native: _NativeRegistrarBox

  public init() {
    native = _NativeRegistrarBox()
  }

  public func access<Subject: AnyObject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    backport.access(subject, keyPath: keyPath)
    native.access(subject, keyPath: keyPath)
  }

  public func withMutation<Subject: AnyObject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    backport.willSet(subject, keyPath: keyPath)
    return try native.withMutation(of: subject, keyPath: keyPath, mutation)
  }

  public func accessAnyKeyPath(_ keyPath: AnyKeyPath) {
    backport.accessAnyKeyPath(keyPath)
  }

  public func willSetAnyKeyPath(_ keyPath: AnyKeyPath) {
    backport.willSetAnyKeyPath(keyPath)
  }

  /// Fires `willSet` for a per-property access on the given subject.
  ///
  /// Typed-keyPath counterpart to ``access(_:keyPath:)`` and
  /// ``withMutation(of:keyPath:_:)``, kept as the symmetric API surface
  /// for future per-property fan-outs even though no current caller
  /// uses it. ObservedReactor's per-property path currently routes
  /// through ``willSetAnyKeyPath(_:)`` for the backport channel only.
  public func willSet<Subject: AnyObject, Member>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    backport.willSet(subject, keyPath: keyPath)
    native.willSet(of: subject, keyPath: keyPath)
  }
}

// MARK: - Native registrar box

/// Wraps the native `ObservationRegistrar` behind a compile-time and runtime availability gate.
/// When `Observation` is unavailable at compile time or the OS is below iOS 17, all methods are no-ops
/// that simply forward the mutation closure.
private struct _NativeRegistrarBox: @unchecked Sendable {
  #if canImport(Observation)
  private let registrar: (any Sendable)?

  init() {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
      registrar = ObservationRegistrar()
    } else {
      registrar = nil
    }
  }

  func access<Subject: AnyObject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = registrar as? ObservationRegistrar,
      let subject = subject as? any Observation.Observable
    {
      // Open the existential to satisfy the `S: Observable` constraint.
      // `unsafeBitCast` recasts `KeyPath<Subject, Member>` to `KeyPath<S, Member>` — safe
      // because Subject and S are the same runtime object; only the static type differs.
      func open<S: Observation.Observable>(_ subject: S) {
        registrar.access(subject, keyPath: unsafeBitCast(keyPath, to: KeyPath<S, Member>.self))
      }
      open(subject)
    }
  }

  func withMutation<Subject: AnyObject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = registrar as? ObservationRegistrar,
      let subject = subject as? any Observation.Observable
    {
      func open<S: Observation.Observable>(_ subject: S) throws -> T {
        try registrar.withMutation(of: subject, keyPath: unsafeBitCast(keyPath, to: KeyPath<S, Member>.self), mutation)
      }
      return try open(subject)
    }
    return try mutation()
  }

  func willSet<Subject: AnyObject, Member>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    if
      #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
      let registrar = registrar as? ObservationRegistrar,
      let subject = subject as? any Observation.Observable
    {
      func open<S: Observation.Observable>(_ subject: S) {
        registrar.willSet(subject, keyPath: unsafeBitCast(keyPath, to: KeyPath<S, Member>.self))
      }
      open(subject)
    }
  }

  #else
  init() {}

  func access<Subject: AnyObject, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {}

  func withMutation<Subject: AnyObject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try mutation()
  }

  func willSet<Subject: AnyObject, Member>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {}
  #endif
}
