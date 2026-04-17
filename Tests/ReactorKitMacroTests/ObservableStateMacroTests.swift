//
//  ObservableStateMacroTests.swift
//  ReactorKitMacroTests
//
//  Created by Kanghoon Oh on 4/11/26.
//

import XCTest

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import ReactorKitMacros

final class ObservableStateMacroTests: XCTestCase {
  private let macros: [String: Macro.Type] = [
    "ObservableState": ObservableStateMacro.self,
    "ObservableStateTracked": ObservableStateTrackedMacro.self,
    "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
  ]

  // MARK: - Member + Accessor Full Expansion

  func testFullExpansionWithStoredVars() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var count: Int = 0
        var isLoading: Bool = false
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0
          var isLoading: Bool {
              @storageRestrictions(initializes: _isLoading)
              init(initialValue) {
                _isLoading = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.isLoading)
                return _isLoading
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.isLoading, &_isLoading, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.isLoading, &_isLoading)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.isLoading, &_isLoading)
                }
                yield &_isLoading
              }
          }

          private  var _isLoading: Bool = false

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testLetPropertiesSkipped() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        let name: String
      }
      """,
      expandedSource: """
        struct State {
          let name: String

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testComputedPropertiesSkipped() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var computed: String { "hello" }
      }
      """,
      expandedSource: """
        struct State {
          var computed: String { "hello" }

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testMixedProperties() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var count: Int = 0
        let name: String
        var computed: String { "hello" }
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0
          let name: String
          var computed: String { "hello" }

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  // MARK: - Accessor Macro Tests (ObservableStateTracked directly)

  func testAccessorExpansionForStoredVar() {
    assertMacroExpansion(
      """
      struct State {
        @ObservableStateTracked
        var count: Int = 0
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0
        }
        """,
      macros: macros
    )
  }

  func testAccessorSkipsLetProperty() {
    assertMacroExpansion(
      """
      struct State {
        @ObservableStateTracked
        let name: String
      }
      """,
      expandedSource: """
        struct State {
          let name: String
        }
        """,
      macros: macros
    )
  }

  func testAccessorSkipsComputedProperty() {
    assertMacroExpansion(
      """
      struct State {
        @ObservableStateTracked
        var computed: String { "hello" }
      }
      """,
      expandedSource: """
        struct State {
          var computed: String { "hello" }
        }
        """,
      macros: macros
    )
  }

  // MARK: - @ObservableStateIgnored

  func testIgnoredPropertyNotTracked() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var count: Int = 0
        @ObservableStateIgnored
        var cache: [String] = []
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0
          var cache: [String] = []

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testAllPropertiesIgnored() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        @ObservableStateIgnored
        var cache: [String] = []
        @ObservableStateIgnored
        var temp: Int = 0
      }
      """,
      expandedSource: """
        struct State {
          var cache: [String] = []
          var temp: Int = 0

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  // MARK: - Edge Cases

  func testEmptyStruct() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
      }
      """,
      expandedSource: """
        struct State {

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testStructWithOnlyLetProperties() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        let id: Int
        let name: String
      }
      """,
      expandedSource: """
        struct State {
          let id: Int
          let name: String

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testStructWithOnlyComputedProperties() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var greeting: String { "hello" }
        var farewell: String { "bye" }
      }
      """,
      expandedSource: """
        struct State {
          var greeting: String { "hello" }
          var farewell: String { "bye" }

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testPublicProperty() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        public var count: Int = 0
      }
      """,
      expandedSource: """
        struct State {
          public var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testPrivateProperty() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        private var secret: String = ""
      }
      """,
      expandedSource: """
        struct State {
          private var secret: String {
              @storageRestrictions(initializes: _secret)
              init(initialValue) {
                _secret = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.secret)
                return _secret
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.secret, &_secret, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.secret, &_secret)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.secret, &_secret)
                }
                yield &_secret
              }
          }

          private  var _secret: String = ""

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testMultipleStoredVarsGenerateBackingStorage() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var a: Int = 1
        var b: String = "hello"
        var c: Bool = false
      }
      """,
      expandedSource: """
        struct State {
          var a: Int {
              @storageRestrictions(initializes: _a)
              init(initialValue) {
                _a = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.a)
                return _a
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.a, &_a, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.a, &_a)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.a, &_a)
                }
                yield &_a
              }
          }

          private  var _a: Int = 1
          var b: String {
              @storageRestrictions(initializes: _b)
              init(initialValue) {
                _b = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.b)
                return _b
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.b, &_b, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.b, &_b)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.b, &_b)
                }
                yield &_b
              }
          }

          private  var _b: String = "hello"
          var c: Bool {
              @storageRestrictions(initializes: _c)
              init(initialValue) {
                _c = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.c)
                return _c
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.c, &_c, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.c, &_c)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.c, &_c)
                }
                yield &_c
              }
          }

          private  var _c: Bool = false

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testStoredVarWithoutInitializer() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var name: String
      }
      """,
      expandedSource: """
        struct State {
          var name: String {
              @storageRestrictions(initializes: _name)
              init(initialValue) {
                _name = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.name)
                return _name
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.name, &_name, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.name, &_name)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.name, &_name)
                }
                yield &_name
              }
          }

          private  var _name: String

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testOptionalStoredVar() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var title: String? = nil
      }
      """,
      expandedSource: """
        struct State {
          var title: String? {
              @storageRestrictions(initializes: _title)
              init(initialValue) {
                _title = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.title)
                return _title
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.title, &_title, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.title, &_title)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.title, &_title)
                }
                yield &_title
              }
          }

          private  var _title: String? = nil

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testPropertyWrapperPropertySkipped() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var count: Int = 0
        @Pulse var alertMessage: String?
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0
          @Pulse
          var alertMessage: String?

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }

  func testExtensionMacroGeneratesConformance() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var count: Int = 0
      }
      """,
      expandedSource: """
        struct State {
          var count: Int {
              @storageRestrictions(initializes: _count)
              init(initialValue) {
                _count = initialValue
              }
              get {
                _$observationRegistrar.access(self, keyPath: \\Self.count)
                return _count
              }
              set {
                _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, _$isIdentityEqual, shouldNotifyObservers)
              }
              _modify {
                _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                defer {
                  _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                }
                yield &_count
              }
          }

          private  var _count: Int = 0

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }

        extension State: ReactorKitObservation.ObservableState {
        }
        """,
      macroSpecs: [
        "ObservableState": MacroSpec(
          type: ObservableStateMacro.self,
          conformances: ["ReactorKitObservation.ObservableState"]
        ),
        "ObservableStateTracked": MacroSpec(type: ObservableStateTrackedMacro.self),
        "ObservableStateIgnored": MacroSpec(type: ObservableStateIgnoredMacro.self),
      ]
    )
  }

  func testDollarPrefixedPropertySkipped() {
    assertMacroExpansion(
      """
      @ObservableState
      struct State {
        var _$internalProp: Int = 0
      }
      """,
      expandedSource: """
        struct State {
          var _$internalProp: Int = 0

            var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()

            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
              true
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs !== rhs
            }

            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
              lhs != rhs
            }

            mutating func _$willModify() {
              _$observationRegistrar._$willModify()
            }
        }
        """,
      macros: macros
    )
  }
}
