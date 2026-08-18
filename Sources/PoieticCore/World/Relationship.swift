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


/// Specifies how many relationships of a given type an entity can have.
///
/// Used by ``Relationship/outgoingCardinality`` to constrain the number of outgoing
/// relationships from a single origin entity.
public enum Cardinality: Sendable, Equatable {
    /// The entity can have at most one outgoing relationship of this type.
    /// Setting a new relationship replaces any existing one.
    case one
    /// The entity can have any number of outgoing relationships of this type.
    case many
}

/// A component that represents a directed relationship between two entities.
///
/// Relationships connect an *origin* entity to a *target* entity. Unlike regular components
/// which are attached to a single entity, relationships are edges stored in a separate
/// storage, indexed bidirectionally for efficient traversal in both directions.
///
/// Each relationship type declares:
/// - ``targetRemovalPolicy`` — what happens to the origin when the target is despawned
/// - ``outgoingCardinality`` — how many targets a single origin can point to
///
/// ## Usage in Entity
///
/// - **Creation**: ``RuntimeEntity/relates(_:to:)-(_,RuntimeEntity)``
/// - **Navigation**:``RuntimeEntity/incoming(_:)``, ``RuntimeEntity/outgoing(_:)``,
/// ``RuntimeEntity/firstOutgoing(_:)``.
/// - **Hierarchy** (convenience with ``ChildOf``): ``RuntimeEntity/parent``, ``RuntimeEntity/children``.
///
/// ## Built-in relationship types
///
/// - ``ChildOf`` – parent-child hierarchy, despawned with target
/// - ``MemberOf`` – non-hierarchical ownership dependency, despawned with target
/// - ``RepresentationOf`` – Visual/semantic representation, despawned with target
///
public protocol Relationship: Component {
    /// Defines what happens to the origin entity when the target entity is despawned.
    ///
    /// - ``RelationshipRemovalPolicy/despawn``: The origin is despawned together with the target.
    /// - ``RelationshipRemovalPolicy/remove``: Only the relationship edge is removed; the origin survives.
    /// - ``RelationshipRemovalPolicy/fatalError``: The application crashes — used when a dangling
    ///   relationship indicates a programming error.
    static var targetRemovalPolicy: RelationshipRemovalPolicy { get }

    /// How many outgoing relationships of this type a single origin entity can have.
    ///
    /// ``Cardinality/one`` – at most one. Setting a new relationship replaces any previous one.
    /// Useful for singular references such as a ``ChildOf`` parent.
    ///
    /// ``Cardinality/many`` – unlimited. Useful for collections such as `Depicts` where a
    /// diagram references many blocks.
    ///
    /// Defaults to ``Cardinality/one``.
    static var outgoingCardinality: Cardinality { get }

    // No use for incoming cardinality yet.
    //    static var incomingCardinality: Cardinality { get }

    // TODO: insert/removal hooks
}

extension Relationship {
    public static var outgoingCardinality: Cardinality { .one }
    // TODO: Add incomingCardinality following once needed
}

// MARK: - Relationship Components

/// Indicates that an entity is a child of another entity
public struct ChildOf: Relationship {
    /// When parent is removed, remove the child
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}

/// Indicates ownership-membership. Target is the owner of the member. When the owner is removed,
/// the member entity is removed with it.
///
/// This is a dependency relationship unrelated to parent-child hierarchy. It might be used
/// for skipping hierarchy directly to root of hierachy.
///
public struct MemberOf: Relationship {
    /// When owner is removed, remove the owned entity
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}

/// Relationship indicating that an entity is a representation of another – represented entity.
/// For example a visual canvas object with a pictogram represents a design block entity.
///
/// When the represented object is removed, the representation entity is removed as well.
///
public struct RepresentationOf: Relationship {
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}

/// Relationship indicating that an entity – controller controls a target – controlled entity.
/// For example a visual slider controls a value of a simulation property.
///
/// When the target is removed, the relationship is removed, keeping the component owning entity.
///
/// For a similar relationship where the controller is removed with the controlled see ``Handles``.
public struct Controls: Relationship {
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .remove
    public static var outgoingCardinality: Cardinality { .many }
    public init() { /* Empty */ }
}

/// Relationship indicating that an entity – a handle controls a property of a target
/// – handled entity.
///
/// For example a visual canvas handle controls a position of another object or a midpoint of a
/// connector.
///
/// When the target is removed, the handler entity is removed, keeping the component owning entity.
///
public struct Handles: Relationship {
    // TODO: Maybe pick a better name for the relationship component. Maybe "Manipulates"?
    public static let targetRemovalPolicy: RelationshipRemovalPolicy = .despawn
    public static var outgoingCardinality: Cardinality { .one }
    public init() { /* Empty */ }
}
