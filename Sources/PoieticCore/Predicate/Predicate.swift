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
public protocol Predicate: Sendable, CustomStringConvertible {
    /// Check whether an object matches the predicate condition.
    ///
    func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool

    /// Creates a compound predicate with the other predicate using a logical ∧ – `and` connective.
    func and(_ predicate: Predicate) -> Predicate

    /// Creates a compound predicate with the other predicate using a logical ⋁ – `or` connective.
    func or(_ predicate: Predicate) -> Predicate
    
    /// Creates a predicate that is a negation of the receiver.
    func not() -> Predicate
}

extension Predicate {
    public func and(_ predicate: Predicate) -> Predicate {
        return AndPredicate(self, predicate)
    }
    public func or(_ predicate: Predicate) -> Predicate {
        return OrPredicate(self, predicate)
    }
    public func not() -> Predicate {
        return NegationPredicate(self)
    }
}

/// Logical disjunction of multiple predicates.
///
/// At least one of the predicates must match.
///
public struct OrPredicate: Predicate, CustomStringConvertible {
    /// List of predicates that are evaluated together.
    public let predicates: [Predicate]
    
    /// Create a new logical disjunction predicate.
    ///
    /// - Parementes:
    ///     - predicates: List of predicates to connect.
    ///
    public init(_ predicates: any Predicate...) {
        self.predicates = predicates
    }
    
    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        predicates.contains{ $0.match(object, in: frame) }
    }

    public var description: String {
        let items = predicates.map { $0.description }.joined(separator: " OR ")
        return "(\(items))"
    }
}

/// Logical conjunction of multiple predicates.
///
/// All contained predicates must match.
///
public struct AndPredicate: Predicate, CustomStringConvertible {
    /// List of predicates that are evaluated together.
    public let predicates: [Predicate]
    
    /// Create a new logical disjunction predicate.
    ///
    /// - Parementes:
    ///     - predicates: List of predicates to connect.
    ///
    public init(_ predicates: any Predicate...) {
        self.predicates = predicates
    }
    
    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        predicates.allSatisfy{ $0.match(object, in: frame) }
    }

    public var description: String {
        let items = predicates.map { $0.description }.joined(separator: " AND ")
        return "(\(items))"
    }
}

public struct NegationPredicate: Predicate, CustomStringConvertible {
    public let predicate: Predicate
    public init(_ predicate: any Predicate) {
        self.predicate = predicate
    }
    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        return !predicate.match(object, in: frame)
    }

    public var description: String { "NOT(\(predicate)" }
}
/// Predicate that matches any object.
///
public struct AnyPredicate: Predicate, CustomStringConvertible{
    public init() {}
    
    /// Matches any node – always returns `true`.
    ///
    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        return true
    }

    public var description: String { "ANY" }
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

    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        return object.components.has(self.type)
    }
    public var description: String { "component(\(type)" }

}

/// Predicate to test whether an object has a given trait.
///
public struct HasTraitPredicate: Predicate, CustomStringConvertible {
    /// Trait to be tested for.
    let trait: Trait
    
    /// Create a new predicate to test for a trait.
    public init(_ trait: Trait) {
        self.trait = trait
    }

    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        object.type.traits.contains { $0 === trait }
    }
    public var description: String { "HAS(\(trait.name))" }

}

/// Predicate to test whether an object is of one or multiple given types.
///
public struct IsTypePredicate: Predicate, CustomStringConvertible {
    /// List of types to test for.
    let type: ObjectType
    
    /// Create a new predicate with a type to test for.
    public init(_ type: ObjectType) {
        self.type = type
    }
    
    public func match(_ object: ObjectSnapshot, in frame: some Frame) -> Bool {
        object.type === type
    }
    
    public var description: String { "IS(\(type.name))" }
}
