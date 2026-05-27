//
//  EphemeralObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2025.
//

/// Ephemeral identity of a runtime entity.
///
/// Each entity in the ``World`` is represented by a runtime ID, which is valid only during the
/// lifetime of the World.
///
/// Design entities are given a runtime ID when presented in a world, for example through
/// ``World/setFrame(_:)``.
///
/// Runtime IDs are not persisted within the library and it is not recommended to store them.
///
///
/// - SeeAlso: ``DesignEntityID``, ``World/spawn(_:)``
///
/// - Note: The `RuntimeID` type is semantically equivalent to `EntityID` types in other
///   Entity-Component-System libraries. We are calling it `RuntimeID` to prevent naming
///   ambiguity with ``DesignEntityID``.
///   
public struct RuntimeID:
    Hashable,
    CustomStringConvertible,
    ExpressibleByIntegerLiteral,
    Sendable
{
    public typealias IntegerLiteralType = UInt64
    let value: UInt64
    
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
    
    public init(intValue: UInt64) {
        self.value = intValue
    }

    public var asUInt64: UInt64 { self.value }
    
    public var description: String { String(value) }
}

/// Structure representing a runtime, in-memory non-persistent entity that lives in a ``World``.
///
/// Entities are identified by ``RuntimeID``.
///
public struct RuntimeEntity {
    public let runtimeID: RuntimeID
    public unowned let world: World
    
    /// Get
    public var objectID: ObjectID? { world.entityToObjectMap[runtimeID] }
    
    /// Get corresponding design object that is being represented by the runtime entity, if it
    /// exists in the world's current frame.
    ///
    public var designObject: ObjectSnapshot? {
        guard let objectID = world.entityToObjectMap[runtimeID] else { return nil }
        return world.frame?[objectID]
    }
    
    internal init(runtimeID: RuntimeID, world: World) {
        self.runtimeID = runtimeID
        self.world = world
    }
    
    /// Check if an object has a specific component type
    ///
    /// - Parameters:
    ///   - type: The component type to check
    ///   - runtimeID: The object ID
    /// - Returns: True if the object has the component, otherwise false
    ///
    public func contains<T: Component>(_ type: T.Type) -> Bool {
        return world._containsComponent(type, for: self.runtimeID)
    }

    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - runtimeID: Runtime ID of an object or an ephemeral entity.
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>() -> T? {
        return world._getComponent(T.self, for: self.runtimeID)
    }

    /// Set a component for an entity.
    ///
    /// If a component of the same type already exists for this object,
    /// it will be replaced.
    ///
    /// - Parameters:
    ///   - component: The component to set
    ///   - runtimeID: The object ID
    ///
    /// - Precondition: Entity must exist in the world.
    ///
    public func setComponent<T: Component>(_ component: T) {
        precondition(world.entities.contains(runtimeID))
        world._setComponent(component, for: self.runtimeID)
    }
    
    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - runtimeID: The object ID
    ///
    public func removeComponent<T: Component>(_ type: T.Type) {
        world._removeComponent(type, for: runtimeID)
    }
    
    public func modify<T: Component, Result>(
        _ modification: (inout T) -> Result
    ) -> Result? {
        guard var component: T = component() else {
            return nil
        }
        let result = modification(&component)
        setComponent(component)
        return result
    }

    /// Append a user-facing issue for the entity representing a design object.
    ///
    /// Issues are non-fatal problems with user data. Systems should append
    /// issues here rather than throwing errors, allowing processing to continue
    /// and collect multiple issues.
    ///
    /// - Parameters:
    ///   - issue: The error/issue to append
    ///   - objectID: The object ID associated with the issue
    ///
    ///- Returns: `true` if the entity represents a design object, otherwise false.
    ///
    @discardableResult
    public func appendIssue(_ issue: Issue) -> Bool {
        guard let objectID = self.objectID else { return false }
        world.issues[objectID, default: []].append(issue)
        return false
    }
    
    public var issues: [Issue]? {
        guard let objectID = self.objectID else { return nil }
        return world.issues[objectID]
    }

    public var hasIssues: Bool {
        guard let objectID = self.objectID else { return false }
        if let issues = world.issues[objectID] { return !issues.isEmpty }
        else { return false }
    }
    
    /// Access components via subscript syntax.
    ///
    /// ```swift
    /// // Get a component
    /// if let position = entity[Position.self] {
    ///     print(position.x, position.y)
    /// }
    ///
    /// // Set a component
    /// entity[Position.self] = Position(x: 10, y: 20)
    ///
    /// // Remove a component (by setting to nil)
    /// entity[Position.self] = nil
    ///
    /// ```
    ///
    public subscript<T: Component>(_ type: T.Type) -> T? {
        get {
            return component()
        }
        set {
            if let newValue {
                setComponent(newValue)
            } else {
                removeComponent(type)
            }
        }
    }

}

// MARK: Relationships

extension RuntimeEntity {
    /// List of entity children – entities with ``ChildOf`` relationship component pointing
    /// to this entity.
    public var children: [RuntimeEntity] {
        referrers(ChildOf.self)
    }
    
    public func firstChild<T: Component>(with componentType: T.Type) -> (RuntimeEntity, T)? {
        let all: [(RuntimeEntity, T)] = self.children.compactMap { child in
            guard let component: T = child.component() else { return nil }
            return (child, component)
        }
        return all.first
    }
    /// Get a list of entities referring to this entity by a given relationship type.
    ///
    /// Example:
    ///
    /// ```
    /// let node: RuntimeEntity // Assuming this exists
    /// let children: [RuntimeEntity] = node.referrers(ChildOf.self)
    /// let representations: [RuntimeEntity] = node.referrers(RepresentationOf.self)
    /// ```
    ///
    public func referrers<T:Relationship>(_ type: T.Type) -> [RuntimeEntity] {
        let id = ObjectIdentifier(T.self)
        guard let deps = world.dependencies[self.runtimeID] else { return [] }
        return deps.filter { $0.componentTypeID == id }
                .map { RuntimeEntity(runtimeID: $0.sourceID, world: world) }

    }

    /// Get a target of a relationship if the relationship is present.
    ///
    public func target<T: Relationship>(_ type: T.Type) -> RuntimeEntity? {
        guard let component: T = self.component() else { return nil }
        return RuntimeEntity(runtimeID: component.other, world: self.world)
    }
}

struct ReferrerCollection<T: Relationship> {
    typealias RelationshipType = T
    let entity: RuntimeEntity
    let relationshipType: ObjectIdentifier
    
    var entities: [RuntimeEntity] {
        guard let deps = entity.world.dependencies[entity.runtimeID] else { return [] }
        return deps.filter { $0.componentTypeID == relationshipType }
            .map { RuntimeEntity(runtimeID: $0.sourceID, world: entity.world) }
    }

    init(entity: RuntimeEntity) {
        self.entity = entity
        self.relationshipType = ObjectIdentifier(T.self)
    }
    
    public func first<C: Component>(with componentType: C.Type) -> (RuntimeEntity, C)? {
        guard let entity = self.entities.first(where: { $0.contains(C.self) }) else { return nil }
        let component: C = entity.component()!
        return (entity, component)
    }

}
extension ReferrerCollection: Sequence {
    typealias Element = RuntimeEntity
    typealias Iterator = [RuntimeEntity].Iterator
    
    func makeIterator() -> Iterator {
        self.entities.makeIterator()
    }
}
