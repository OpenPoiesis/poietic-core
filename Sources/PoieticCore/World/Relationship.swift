//
//  Relationship.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 27/02/2026.
//

/// Defines cleanup behaviour when the target of a relationship is removed
public enum RemovalPolicy: Sendable, Equatable {
    /// Remove the entity holding this relationship component
    case removeSelf
    
    /// Remove just this relationship component from the source
    case removeRelationship
    
    // Remove the target entity
    // case removeTarget
    
    /// Do nothing automatically (manual cleanup required)
    case none
}


/// A component that represents a relationship between two entities
public protocol Relationship: Component {
    
    /// The target entity this relationship points to
    var target: RuntimeID { get }
    
    /// Defines what happens when the target entity is removed
    static var removalPolicy: RemovalPolicy { get }
    
    // TODO: insert/removal hooks
}

// MARK: - Relationship Components

/// Indicates that an entity is a child of another entity
public struct ChildOf: Relationship {
    public let target: RuntimeID
    
    /// When parent is removed, remove the child
    public static let removalPolicy: RemovalPolicy = .removeSelf
    
    public init(_ parent: RuntimeID) {
        self.target = parent
    }
}

/// Indicates ownership - when owner is removed, remove the owned entity
public struct OwnedBy: Relationship {
    public let target: RuntimeID
    
    /// When owner is removed, remove the owned entity
    public static let removalPolicy: RemovalPolicy = .removeSelf
    
    public init(_ owner: RuntimeID) {
        self.target = owner
    }
}
