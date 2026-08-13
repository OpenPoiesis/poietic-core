//
//  Predicate.swift
//
//  Created by Stefan Urbanek on 13/06/2022.
//

/// A type that defines and matches characteristics of an object.
///
/// Match properties of an object with ``match(_:in:)``.
///
/// Predicates can be composed using logical operations ``and(_:)`` and ``or(_:)``. For example:
///
/// ```swift
/// let predicate: Predicate = .isType(ObjectType.Auxiliary).or(.isType(ObjectType.Stock))
/// ```
///
public indirect enum Predicate: Sendable, CustomStringConvertible {
    /// Matches any object unconditionally
    case any
    /// Matches objects of given object type
    case isType(ObjectType)
    /// Matches objects which have given trait.
    case hasTrait(Trait)
    /// Logical conjunction of multiple predicates –  all predicates must match.
    case and([Predicate])
    /// Logical disjunction of multiple predicates – at least one of the predicates must match.
    case or([Predicate])
    /// Matches objects where the given predicate is not true.
    case not(Predicate)

    /// Check whether an object matches the predicate condition.
    ///
    public func match(_ object: ObjectSnapshot, in plane: some Plane) -> Bool {
        switch self {
        case .any:
            return true
        case .isType(let type):
            return object.type === type
        case .hasTrait(let trait):
            return object.type.traits.contains { $0 === trait }
        case .and(let predicates):
            return predicates.allSatisfy{ $0.match(object, in: plane) }
        case .or(let predicates):
            return predicates.contains{ $0.match(object, in: plane) }
        case .not(let predicate):
            return !predicate.match(object, in: plane)
        }
    }

    /// Creates a compound predicate with the other predicate using a logical ∧ – `and` connective.
    public func and(_ other: Predicate) -> Predicate {
        switch self {
        case .and(let predicates): .and(predicates + [other])
        default: .and([self, other])
        }
    }

    /// Creates a compound predicate with the other predicate using a logical ⋁ – `or` connective.
    public func or(_ other: Predicate) -> Predicate {
        switch self {
        case .or(let predicates): .or(predicates + [other])
        default: .or([self, other])
        }
    }

    /// Creates a predicate that is a negation of the receiver.
    public func not() -> Predicate {
        return .not(self)
    }
    
    /// Get direct children predicates.
    public var children: [Predicate] {
        switch self {
        case .and(let predicates): return predicates
        case .any: return []
        case .hasTrait(_): return []
        case .isType(_): return []
        case .not(let predicate): return [predicate]
        case .or(let predicates): return predicates
        }
    }
    
    public var description: String {
        switch self {
        case .any:
            return "ANY"
        case .isType(let type):
            return "IS(\(type.name))"
        case .hasTrait(let trait):
            return "HAS(\(trait.name))"
        case .and(let predicates):
            let items = predicates.map { $0.description }.joined(separator: " AND ")
            return "(\(items))"
        case .or(let predicates):
            let items = predicates.map { $0.description }.joined(separator: " OR ")
            return "(\(items))"
        case .not(let predicate):
            return "NOT(\(predicate))"
        }
    }
}
