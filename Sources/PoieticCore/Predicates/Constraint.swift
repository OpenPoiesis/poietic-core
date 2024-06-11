//
//  File.swift
//  
//
//  Created by Stefan Urbanek on 13/06/2022.
//

public struct ConstraintViolation: Error {
    public let constraint: Constraint
    public let objects: [ObjectID]
    
    public init(constraint: Constraint,
                objects: [ObjectID] = []) {
        self.constraint = constraint
        self.objects = objects
    }
}

/// An object representing constraint that checks edges.
///
public final class Constraint: Sendable {
    /// Identifier of the constraint.
    ///
    /// - Important: It is highly recommended that the constraint names are
    /// unique within an application, to communicate issues to the user clearly.
    ///
    public let name: String
    
    // TODO: Rename to non-conflicting attribute, like "message"
    /// Human-readable description of the constraint. The recommended content
    /// can be:
    ///
    /// - What an edge or a node must be?
    /// - What an edge or a node must have?
    /// - What an edge endpoint - origin or target - must point to?
    ///
    public let abstract: String?

    /// A predicate that matches all edges to be considered for this constraint.
    ///
    /// See ``Predicate`` for more information.
    ///
    public let match: Predicate
    
    /// A requirement that needs to be satisfied for the matched objects.
    ///
    public let requirement: ConstraintRequirement
    
    /// Creates an edge constraint.
    ///
    /// - Properties:
    ///
    ///     - name: Constraint name
    ///     - description: Constraint description
    ///     - match: an edge predicate that matches edges to be considered for
    ///       this constraint
    ///     - requirement: a requirement that needs to be satisfied by the
    ///       matched edges.
    ///
    public init(name: String,
                abstract: String? = nil,
                match: Predicate,
                requirement: ConstraintRequirement) {
        self.name = name
        self.abstract = abstract
        self.match = match
        self.requirement = requirement
    }

    /// Check the frame for the constraint and return a list of nodes that
    /// violate the constraint
    ///
    public func check(_ frame: Frame) -> [ObjectID] {
        let matched = frame.snapshots.filter {
            match.match(frame: frame, object: $0)
        }
        // .map { $0.snapshot }
        return requirement.check(frame: frame, objects: matched)
    }
}

/// Definition of a constraint satisfaction requirement.
///
public protocol ConstraintRequirement: Sendable {
    /// - Returns: List of IDs of objects that do not satisfy the requirement.
    func check(frame: Frame, objects: [ObjectSnapshot]) -> [ObjectID]
}

/// Requirement that all matched objects satisfy a given predicate.
public final class AllSatisfy: ConstraintRequirement {
    /// Predicate to be satisfied by the requirement.
    public let predicate: Predicate
    
    /// Create a new requirement for objects that must satisfy the given
    /// predicate.
    public init(_ predicate: Predicate) {
        self.predicate = predicate
    }

    public func check(frame: Frame, objects: [ObjectSnapshot]) -> [ObjectID] {
        objects.filter { !predicate.match(frame: frame, object: $0) }
            .map { $0.id }
    }
}


/// A constraint requirement that is used to specify object (edges or nodes)
/// that are prohibited. If the constraint requirement is used, then it
/// matches all objects defined by constraint predicate and rejects them all.
///
public final class RejectAll: ConstraintRequirement {
    /// Creates an object constraint requirement that rejects all objects.
    ///
    public init() {
    }
   
    /// Returns all objects it is provided – meaning, that all of them are
    /// violating the constraint.
    ///
    public func check(frame: Frame, objects: [ObjectSnapshot]) -> [ObjectID] {
        /// We reject whatever comes in
        return objects.map { $0.id }
    }
}

/// A constraint requirement that is used to specify object (edges or nodes)
/// that are required. If the constraint requirement is used, then it
/// matches all objects defined by constraint predicate and accepts them all.
///
public final class AcceptAll: ConstraintRequirement {
    /// Creates an object constraint requirement that accepts all objects.
    ///
    public init() {
    }
   
    /// Returns an empty list, meaning that none of the objects are violating
    /// the constraint.
    ///
    public func check(frame: Frame, objects: [ObjectSnapshot]) -> [ObjectID] {
        // We accept everything, therefore we do not return any violations.
        return []
    }
}

/// A constraint requirement that a specified property of the objects must
/// be unique within the checked group of checked objects.
///
public final class UniqueProperty: ConstraintRequirement {
    
    /// Property name to be checked for uniqueness.
    public let name: String
    
    /// Creates a unique property constraint requirement with a function
    /// that extracts a property from a graph object.
    ///
    public init(_ name: String) {
        self.name = name
    }
    
    /// Checks the objects for the requirement. The function extracts the
    /// value from each of the objects and returns a list of those objects
    /// that have duplicate values.
    /// 
    public func check(frame: Frame, objects: [ObjectSnapshot]) -> [ObjectID] {
        var seen: [Variant:[ObjectID]] = [:]
        
        for object in objects {
            guard let value = object[name] else {
                continue
            }
            seen[value, default: []].append(object.id)
        }
        
        let duplicates = seen.filter {
            $0.value.count > 1
        }.flatMap {
            $0.value
        }
        return duplicates
    }
}
