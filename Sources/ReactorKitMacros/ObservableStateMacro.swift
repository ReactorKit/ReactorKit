//
//  ObservableStateMacro.swift
//  ReactorKitMacros
//
//  Created by Kanghoon Oh on 4/11/26.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Syntax helpers

extension DeclModifierListSyntax {
  /// Returns a copy of this modifier list with any existing access-control
  /// modifier replaced by `private`. Used when cloning a user-declared
  /// property into its `_`-prefixed backing storage — the storage should be
  /// inaccessible regardless of what visibility the user gave the original.
  fileprivate func privatePrefixed() -> DeclModifierListSyntax {
    let privateModifier = DeclModifierSyntax(
      name: .keyword(.private, trailingTrivia: .space)
    )
    let filtered = filter { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.fileprivate),
           .keyword(.private),
           .keyword(.internal),
           .keyword(.public),
           .keyword(.package):
        return false
      default:
        return true
      }
    }
    return DeclModifierListSyntax(Array([privateModifier] + filtered))
  }

  /// Returns the access-control keyword that must be propagated to
  /// macro-generated members that act as **witnesses for public-protocol
  /// requirements** (specifically `_$observationRegistrar` and
  /// `_$willModify()`, which satisfy the public `ObservableState`
  /// protocol).
  ///
  /// Swift requires a witness to be at least as accessible as the
  /// conformance. For `public struct S: ObservableState`, the
  /// conformance is public and its witnesses must be public too. For
  /// an internal / private struct, default (internal) visibility on
  /// witnesses is enough — more visible than the conformance scope
  /// works, so returning `nil` is correct.
  ///
  /// Only `public` and `package` need explicit propagation — every
  /// other access level lives happily with default internal witnesses.
  fileprivate var _$witnessAccessModifier: String? {
    for modifier in self {
      switch modifier.name.tokenKind {
      case .keyword(.public): return "public"
      case .keyword(.package): return "package"
      default: continue
      }
    }
    return nil
  }
}

extension TokenSyntax {
  fileprivate func prefixedWithUnderscore() -> TokenSyntax {
    switch tokenKind {
    case .identifier(let identifier):
      return TokenSyntax(
        .identifier("_" + identifier),
        leadingTrivia: leadingTrivia,
        trailingTrivia: trailingTrivia,
        presence: presence
      )
    default:
      return self
    }
  }
}

extension PatternBindingListSyntax {
  /// Returns a copy of this binding list where every identifier pattern is
  /// renamed with an underscore prefix. Type annotations and initializers
  /// are preserved verbatim so type inference from the user's source is
  /// retained on the backing storage.
  fileprivate func prefixedWithUnderscore() -> PatternBindingListSyntax {
    var bindings = Array(self)
    for index in bindings.indices {
      let binding = bindings[index]
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
      else { continue }
      bindings[index] = PatternBindingSyntax(
        leadingTrivia: binding.leadingTrivia,
        pattern: IdentifierPatternSyntax(
          leadingTrivia: identifierPattern.leadingTrivia,
          identifier: identifierPattern.identifier.prefixedWithUnderscore(),
          trailingTrivia: identifierPattern.trailingTrivia
        ),
        typeAnnotation: binding.typeAnnotation,
        initializer: binding.initializer,
        accessorBlock: binding.accessorBlock,
        trailingComma: binding.trailingComma,
        trailingTrivia: binding.trailingTrivia
      )
    }
    return PatternBindingListSyntax(bindings)
  }
}

extension VariableDeclSyntax {
  /// Clones this variable declaration for use as `_`-prefixed backing
  /// storage. The clone:
  /// - prepends the identifier with `_`
  /// - forces `private` visibility
  /// - appends `attribute` to the attribute list
  /// - preserves the original type annotation and initializer (so `var x = 0`
  ///   stays type-inferred)
  fileprivate func clonedAsBackingStorage(
    addingAttribute attribute: AttributeSyntax
  ) -> VariableDeclSyntax {
    let newAttributes = attributes + [.attribute(attribute)]
    return VariableDeclSyntax(
      leadingTrivia: leadingTrivia,
      attributes: newAttributes,
      modifiers: modifiers.privatePrefixed(),
      bindingSpecifier: TokenSyntax(
        bindingSpecifier.tokenKind,
        leadingTrivia: .space,
        trailingTrivia: .space,
        presence: .present
      ),
      bindings: bindings.prefixedWithUnderscore(),
      trailingTrivia: trailingTrivia
    )
  }

  fileprivate func hasAttribute(named name: String) -> Bool {
    attributes.contains { element in
      guard case .attribute(let attr) = element else { return false }
      return attr.attributeName.trimmedDescription == name
    }
  }
}

// MARK: - ObservableStateMacro

public struct ObservableStateMacro {

  static let trackedMacroName = "ObservableStateTracked"
  static let ignoredMacroName = "ObservableStateIgnored"

  /// Property wrappers this macro supports coexisting with by
  /// auto-marking the host property with `@ObservableStateIgnored`,
  /// so the wrapper's own synthesized accessors take over and the
  /// macro emits no tracked accessors on top.
  ///
  /// Wrappers not on this list receive no special treatment — they
  /// fall through to the normal `@ObservableStateTracked`
  /// instrumentation path and, if their synthesized accessors
  /// collide with the macro's, produce a loud compile error. Users
  /// can opt such wrappers out by writing `@ObservableStateIgnored`
  /// on the property explicitly, matching Apple's native
  /// `@Observable` convention.
  static let knownSupportedPropertyWrappers: Set<String> = [
    "Pulse",
  ]

  static var ignoredAttribute: AttributeSyntax {
    AttributeSyntax(
      leadingTrivia: .space,
      atSign: .atSignToken(),
      attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName)),
      trailingTrivia: .space
    )
  }

  /// Returns `true` when the variable is a stored `var` that is eligible
  /// for observation instrumentation.
  ///
  /// Skips:
  /// - `let` bindings
  /// - computed properties
  /// - `_`-prefixed backing storage already generated by this macro
  ///
  /// Property-wrapper detection is handled separately by
  /// ``hasKnownPropertyWrapper(_:)`` in the member-attribute role.
  static func isStoredVar(_ decl: VariableDeclSyntax) -> Bool {
    guard decl.bindingSpecifier.tokenKind == .keyword(.var) else { return false }
    guard let binding = decl.bindings.first else { return false }

    if
      let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
      pattern.identifier.text.hasPrefix("_")
    {
      return false
    }

    if let accessorBlock = binding.accessorBlock {
      switch accessorBlock.accessors {
      case .getter:
        return false
      case .accessors(let list):
        let hasGetOrSet = list.contains { accessor in
          let kind = accessor.accessorSpecifier.tokenKind
          return kind == .keyword(.get) || kind == .keyword(.set)
            || kind == .keyword(.willSet) || kind == .keyword(.didSet)
        }
        if hasGetOrSet { return false }
      }
    }

    return true
  }

  /// Returns `true` when the variable carries any attribute listed in
  /// ``knownSupportedPropertyWrappers``.
  static func hasKnownPropertyWrapper(_ decl: VariableDeclSyntax) -> Bool {
    knownSupportedPropertyWrappers.contains { name in
      decl.hasAttribute(named: name)
    }
  }

  static func propertyName(_ binding: PatternBindingSyntax) -> String? {
    binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
  }
}

// MARK: - MemberMacro

extension ObservableStateMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    var members = [DeclSyntax]()

    // Propagate the declaring type's access level to members that
    // witness public-protocol requirements. For `public struct State`
    // the witnesses must be `public`; for everything else default
    // internal is fine.
    let witnessModifier = declaration.modifiers._$witnessAccessModifier
      .map { "\($0) " } ?? ""

    members.append(
      "\(raw: witnessModifier)var _$observationRegistrar = ReactorKitObservation.ObservableStateRegistrar()"
    )

    members.append(
      """
      private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
        true
      }
      """
    )
    members.append(
      """
      private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
        lhs != rhs
      }
      """
    )
    members.append(
      """
      private nonisolated func shouldNotifyObservers<Member: AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
        lhs !== rhs
      }
      """
    )
    members.append(
      """
      private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(_ lhs: Member, _ rhs: Member) -> Bool {
        lhs != rhs
      }
      """
    )

    members.append(
      """
      \(raw: witnessModifier)mutating func _$willModify() {
        _$observationRegistrar._$willModify()
      }
      """
    )

    return members
  }
}

// MARK: - ExtensionMacro

extension ObservableStateMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    if protocols.isEmpty { return [] }

    var extensions = [ExtensionDeclSyntax]()
    let protocolNames = Set(protocols.map { $0.trimmedDescription })

    if !protocolNames.isDisjoint(with: Self.observableStateProtocolNames) {
      let ext: DeclSyntax =
        "extension \(type.trimmed): ReactorKitObservation.ObservableState {}"
      extensions.append(ext.cast(ExtensionDeclSyntax.self))
    }

    if !protocolNames.isDisjoint(with: Self.observableProtocolNames) {
      let ext: DeclSyntax =
        """
        @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
        extension \(type.trimmed): Observation.Observable {}
        """
      extensions.append(ext.cast(ExtensionDeclSyntax.self))
    }

    return extensions
  }

  /// Exact names the compiler may pass for the `ObservableState`
  /// conformance (bare or module-qualified).
  private static let observableStateProtocolNames: Set<String> = [
    "ObservableState",
    "ReactorKitObservation.ObservableState",
  ]

  /// Exact names the compiler may pass for the native `Observation.Observable`
  /// conformance.
  private static let observableProtocolNames: Set<String> = [
    "Observable",
    "Observation.Observable",
  ]
}

// MARK: - MemberAttributeMacro

extension ObservableStateMacro: MemberAttributeMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    guard
      let varDecl = member.as(VariableDeclSyntax.self),
      isStoredVar(varDecl)
    else {
      return []
    }

    if varDecl.hasAttribute(named: ignoredMacroName)
      || varDecl.hasAttribute(named: trackedMacroName)
    {
      return []
    }

    if hasKnownPropertyWrapper(varDecl) {
      return ["@ObservableStateIgnored"]
    }

    return ["@ObservableStateTracked"]
  }
}

// MARK: - ObservableStateTrackedMacro

/// Accessor + peer macro applied to individual stored properties by
/// `@ObservableState`.
///
/// - **AccessorMacro**: synthesizes `init`/`get`/`set`/`_modify` accessors
///   that delegate reads/writes through the observation registrar.
/// - **PeerMacro**: synthesizes a `_`-prefixed private peer that carries the
///   actual storage. Cloning the user's declaration verbatim (rather than
///   reconstructing it from parsed type + initializer strings) means
///   `var count = 0` and `var count: Int = 0` both work, because Swift's
///   normal type inference runs on the cloned declaration.
public struct ObservableStateTrackedMacro {}

extension ObservableStateTrackedMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard
      let varDecl = declaration.as(VariableDeclSyntax.self),
      ObservableStateMacro.isStoredVar(varDecl),
      let binding = varDecl.bindings.first,
      let name = ObservableStateMacro.propertyName(binding)
    else {
      return []
    }

    // Cloned backing storage carries both `@ObservableStateTracked` (inherited)
    // and `@ObservableStateIgnored` (added by the peer). Short-circuit on the
    // ignored marker so we don't try to regenerate accessors for the storage.
    if varDecl.hasAttribute(named: ObservableStateMacro.ignoredMacroName) {
      return []
    }

    let backingName = "_\(name)"

    let initAccessor: AccessorDeclSyntax =
      """
      @storageRestrictions(initializes: \(raw: backingName))
      init(initialValue) {
        \(raw: backingName) = initialValue
      }
      """

    let getAccessor: AccessorDeclSyntax =
      """
      get {
        _$observationRegistrar.access(self, keyPath: \\Self.\(raw: name))
        return \(raw: backingName)
      }
      """

    let setAccessor: AccessorDeclSyntax =
      """
      set {
        _$observationRegistrar._$mutate(self, keyPath: \\Self.\(raw: name), &\(
          raw: backingName
        ), newValue, _$isIdentityEqual, shouldNotifyObservers)
      }
      """

    let modifyAccessor: AccessorDeclSyntax =
      """
      _modify {
        _$observationRegistrar.willModify(self, keyPath: \\Self.\(raw: name), &\(raw: backingName))
        defer {
          _$observationRegistrar.didModify(self, keyPath: \\Self.\(raw: name), &\(raw: backingName))
        }
        yield &\(raw: backingName)
      }
      """

    return [initAccessor, getAccessor, setAccessor, modifyAccessor]
  }
}

extension ObservableStateTrackedMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let varDecl = declaration.as(VariableDeclSyntax.self),
      ObservableStateMacro.isStoredVar(varDecl)
    else {
      return []
    }

    // Prevent recursive peer generation: the cloned storage still carries
    // this macro's attribute as part of its attribute list, so without this
    // guard Swift would try to clone the clone.
    if varDecl.hasAttribute(named: ObservableStateMacro.ignoredMacroName) {
      return []
    }

    let storage = DeclSyntax(
      varDecl.clonedAsBackingStorage(addingAttribute: ObservableStateMacro.ignoredAttribute)
    )
    return [storage]
  }
}

// MARK: - ObservableStateIgnoredMacro

/// Marker macro that excludes a property from observation tracking.
///
/// Declared as an `accessor` macro that returns no accessors — the
/// Apple idiom for "no-op attribute on a stored property". It preserves
/// the property's stored-property semantics and lets peer/member-attribute
/// macros look up the marker via attribute name.
public struct ObservableStateIgnoredMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    []
  }
}

// MARK: - Compiler Plugin

@main
struct ReactorKitMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ObservableStateMacro.self,
    ObservableStateTrackedMacro.self,
    ObservableStateIgnoredMacro.self,
  ]
}
