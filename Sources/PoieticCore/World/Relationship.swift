//
//  Relationship.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 27/02/2026.
//

/// Defines cleanup behaviour when the target of a relationship is removed
public enum RelationshipRemovalPolicy: Sendable, Equatable {
    /// Remove the relationship from the source entity
    case remove
    
    /// Despawn the entity that is the origin of the relationship.
    ///
    /// Used for ``ChildOf`` relationships to despawn children together with the parent.
    ///
    case despawn
    
    /// Cause fatal error and crash the application
    case fatalError
}


public enum Cardinality: Sendable, Equatable {
    case one
    case many
}

/// A component that represents a relationship between two entities
public protocol Relationship: Component {
    /// Defines what happens when the target entity is removed
    static var targetRemovalPolicy: RelationshipRemovalPolicy { get }
    static var outgoingCardinality: Cardinality { get }
//    static var incomingCardinality: Cardinality { get }
    // TODO: Cardinality
    // TODO: insert/removal hooks
}

extension Relationship {
    public static var outgoingCardinality: Cardinality { .one }
//    public static var incomingCardinality: Cardinality { .many }
}

// MARK: - Relationship Components

/// Indicates that an entity is a child of another entity
public struct ChildOf: Relationship {
    /// When parent is removed, remove the child
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}

/// Indicates ownership - when owner is removed, remove the owned entity
public struct OwnedBy: Relationship {
    /// When owner is removed, remove the owned entity
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}

/// Indicates representation - when the original is removed, the representation entity is removed.
public struct RepresentationOf: Relationship {
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .remove
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}
