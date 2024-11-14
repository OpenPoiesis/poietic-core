//
//  Predicate.swift
//
//
//  Created by Stefan Urbanek on 13/06/2022.
//

/// An object predicate.
///
/// Predicates check properties of an object using the ``match(_:in:)`` method.
///
/// Predicates can be composed using logical operations ``and(_:)`` and ``or(_:)``. For example:
///
/// ```swift
/// let predicate = IsTypePredicate(ObjectType.Auxiliary)
///                     .or(IsTypePredicate(ObjectType.Stock))
/// ```
///
/// - Note: When adding a new predicate type, please consider its implementability
///         by other, foreign systems.
///
public protocol Predicate: Sendable {
    /// Check whether an object matches the predicate condition.
    ///
    func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool

    /// Creates a compound predicate with the other predicate using a logical ∧ – `and` connective.
    func and(_ predicate: Predicate) -> CompoundPredicate

    /// Creates a compound predicate with the other predicate using a logical ⋁ – `or` connective.
    func or(_ predicate: Predicate) -> CompoundPredicate
    
    /// Creates a predicate that is a negation of the receiver.
    func not() -> Predicate
}

extension Predicate {
    public func and(_ predicate: Predicate) -> CompoundPredicate {
        return CompoundPredicate(.and, predicates: self, predicate)
    }
    public func or(_ predicate: Predicate) -> CompoundPredicate {
        return CompoundPredicate(.or, predicates: self, predicate)
    }
    public func not() -> Predicate {
        return NegationPredicate(self)
    }
}

// TODO: Add &&, || and ! operators

/// Type of logical connective for a compound predicate.
///
/// - SeeAlso: ``CompoundPredicate``
///
public enum LogicalConnective: Sendable {
    /// Logical ∧ – `and` connective.
    ///
    /// - SeeAlso: ``CompoundPredicate/and(_:)``
    case and
    /// Logical ⋁ – `or` connective.
    ///
    /// - SeeAlso: ``CompoundPredicate/or(_:)``
    case or
}

/// Predicate that connects multiple predicates with a logical connective.
///
/// - SeeAlso: ``Predicate/and(_:)``, ``Predicate/or(_:)``
///
public struct CompoundPredicate: Predicate {
    /// Logical connective to connect the predicates with.
    public let connective: LogicalConnective
    
    /// List of predicates that are evaluated together with the same logical connective.
    public let predicates: [Predicate]
    
    /// Create a new compound predicate.
    ///
    /// - Parementes:
    ///     - connective: Logical connective to connect all the provided predicates with.
    ///     - predicates: List of predicates to connect.
    ///
    public init(_ connective: LogicalConnective, predicates: any Predicate...) {
        self.connective = connective
        self.predicates = predicates
    }
    
    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        switch connective {
        case .and: return predicates.allSatisfy{ $0.match(object, in: frame) }
        case .or: return predicates.contains{ $0.match(object, in: frame) }
        }
    }
}

public struct NegationPredicate: Predicate {
    public let predicate: Predicate
    public init(_ predicate: any Predicate) {
        self.predicate = predicate
    }
    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        return !predicate.match(object, in: frame)
    }
}
/// Predicate that matches any object.
///
public struct AnyPredicate: Predicate {
    public init() {}
    
    /// Matches any node – always returns `true`.
    ///
    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        return true
    }
}

/// Predicate to test whether an object has a given trait.
///
public struct HasComponentPredicate: Predicate {
    /// Component to be tested for.
    let type: Component.Type
    
    /// Create a new predicate to test for a component.
    public init(_ type: Component.Type) {
        self.type = type
    }

    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        return object.components.has(self.type)
    }
    
}

/// Predicate to test whether an object has a given trait.
///
public struct HasTraitPredicate: Predicate {
    /// Trait to be tested for.
    let trait: Trait
    
    /// Create a new predicate to test for a trait.
    public init(_ trait: Trait) {
        self.trait = trait
    }

    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        object.type.traits.contains { $0 === trait }
    }
    
}

/// Predicate to test whether an object is of one or multiple given types.
///
public struct IsTypePredicate: Predicate {
    /// List of types to test for.
    let types: [ObjectType]
    
    /// Create a new predicate with a list of types to test for.
    public init(_ types: [ObjectType]) {
        self.types = types
    }

    /// Create a new predicate with a type to test for.
    public init(_ type: ObjectType) {
        self.types = [type]
    }
    
    public func match(_ object: some ObjectSnapshot, in frame: some Frame) -> Bool {
        return types.allSatisfy{
            object.type === $0
        }
    }
}
