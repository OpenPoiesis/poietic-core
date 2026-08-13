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
/// ``World/setPlane(_:)``.
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

/// Light-weight handle referencing a runtime entity in a world.
///
/// Runtime entities are identified by ``RuntimeID``, they are ephemeral, not persisted.
///
public struct RuntimeEntity: CustomDebugStringConvertible {
    /// Primary identifier of the entity within a world the entity belongs to.
    public let runtimeID: RuntimeID
    
    /// World owning the entity.
    public unowned let world: World
    
    /// Design object ID of the entity, if the entity represents a design object.
    ///
    /// - SeeAlso: ``designObject``
    ///
    public var objectID: ObjectID? { world.entityToObjectMap[runtimeID] }
    
    /// Get corresponding design object that is being represented by the runtime entity, if it
    /// exists in the world's current plane.
    ///
    /// - SeeAlso: ``objectID``
    ///
    public var designObject: ObjectSnapshot? {
        guard let objectID = world.entityToObjectMap[runtimeID] else { return nil }
        return world.plane?[objectID]
    }
    
    internal init(runtimeID: RuntimeID, world: World) {
        self.runtimeID = runtimeID
        self.world = world
    }
    
    /// Remove the entity from the world, including its dependants.
    ///
    /// - SeeAlso: ``World/despawn(_:)-(Sequence<RuntimeID>)``
    ///
    public func despawn() {
        self.world.despawn(self.runtimeID)
    }
    
    // MARK: - Components
    
    /// Check if an object has a specific component type
    ///
    /// - Parameters:
    ///   - type: The component type to check
    ///
    /// - Returns: True if the object has the component, otherwise false
    ///
    public func contains<T: Component>(_ type: T.Type) -> Bool {
        return world._containsComponent(type, for: self.runtimeID)
    }

    /// Get a component for a runtime object
    ///
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
    ///
    public func removeComponent<T: Component>(_ type: T.Type) {
        world._removeComponent(type, for: runtimeID)
    }
    
    public func modifyOrSet<T: Component>(
        default component: T,
        _ mutation: (inout T) -> Void)
    {
        if var existing: T = self.component() {
            mutation(&existing)
            setComponent(existing)
        }
        else {
            setComponent(component)
        }
    }
    
    /// Modify a given component if present. If component is not present nothing happens.
    public func modify<T: Component>(_ type: T.Type, _ mutation: (inout T) -> Void) {
        if var existing: T = self.component() {
            mutation(&existing)
            setComponent(existing)
        }
    }
    // MARK: - Relationships
    
    // TODO: Rename to relate(as:to:)
    public func relate<T: Relationship>(_ component: T, to targetID: RuntimeID) {
        world._setRelationship(component, from: self.runtimeID, to: targetID)
    }
    public func relate<T: Relationship>(_ component: T, to target: RuntimeEntity) {
        world._setRelationship(component, from: self.runtimeID, to: target.runtimeID)
    }

    /// Remove all outgoing relationships of the given type from this entity.
    public func unrelate<T: Relationship>(_ type: T.Type) {
        world._removeAllRelationships(T.self, from: runtimeID)
    }

    /// Remove a specific relationship to a target entity.
    public func unrelate<T: Relationship>(_ type: T.Type, to target: RuntimeEntity) {
        world._removeRelationship(T.self, from: runtimeID, to: target.runtimeID)
    }

    public func target<T: Relationship>(_ componentType: T.Type) -> RuntimeEntity? {
        if let target = world._getFirstTarget(T.self, from: self.runtimeID) {
            return RuntimeEntity(runtimeID: target, world: self.world)
        }
        else {
            return nil
        }
    }
    public func relates<T: Relationship>(_ type: T.Type) -> Bool {
        world._containsRelationship(type, from: self.runtimeID)
    }

    public func relates<T: Relationship>(_ type: T.Type, to targetID: RuntimeID) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: targetID)
    }
    public func relates<T: Relationship>(_ type: T.Type, to entity: RuntimeEntity) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: entity.runtimeID)
    }

    @available(*, deprecated, renamed: "relates")
    public func containsRelationship<T: Relationship>(_ type: T.Type) -> Bool {
        world._containsRelationship(type, from: self.runtimeID)
    }

    @available(*, deprecated, renamed: "relates")
    public func containsRelationship<T: Relationship>(_ type: T.Type, to targetID: RuntimeID) -> Bool {
        world._containsRelationship(type, from: self.runtimeID, to: targetID)
    }

    /// List of entity children – entities with ``ChildOf`` relationship component pointing
    /// to this entity.
    ///
    /// This is a convenience property that uses incoming relationships of the entity.
    ///
    public var children: [RuntimeEntity] {
        return world.incoming(ChildOf.self, to: self.runtimeID).map { $0.0 }
    }

    /// Visit children recursively and call function on each child before descending.
    ///
    public func withChildrenRecursively(_ visit: ((RuntimeEntity) -> Void)) {
        for child in children {
            visit(child)
            child.withChildrenRecursively(visit)
        }
    }
    
    /// Get a parent of an entity. Parent is defined by the target of the ``ChildOf`` relationship.
    ///
    /// This is a convenience property that uses outgoing relationships of the entity.
    ///
    public var parent: RuntimeEntity? {
        guard let target = world._getFirstTarget(ChildOf.self, from: self.runtimeID)
        else { return nil }
        
        return RuntimeEntity(runtimeID: target, world: self.world)
    }
        
    /// Get origin entities of given relationships where the target is this entity.
    ///
    /// Example:
    ///
    /// ```
    /// let node: RuntimeEntity // Assuming this exists
    /// let children: [RuntimeEntity] = node.incoming(ChildOf.self)
    /// let representations: [RuntimeEntity] = node.incoming(RepresentationOf.self)
    /// ```
    ///
    public func incoming<T: Relationship>(_ type: T.Type) -> [RuntimeEntity] {
        return world.incoming(T.self, to: self.runtimeID).map { $0.0 }
    }

    /// Get target entities of given relationships where the origin is this entity.
    public func outgoing<T: Relationship>(_ type: T.Type) -> [RuntimeEntity] {
        return world.outgoing(T.self, from: self.runtimeID).map { $0.0 }
    }
    
    /// Get first outgoing relationship of given type.
    ///
    /// - Precondition: The relationship type cardinality ``Relationship/outgoingCardinality`` must
    /// be to-one (``Cardinality/one``). It is considered a programming error to call this
    /// function on to-many relationship.
    ///
    public func firstOutgoing<T: Relationship>(_ type: T.Type) -> RuntimeEntity? {
        precondition(type.outgoingCardinality == .one)
        
        let outgoings = world.outgoing(T.self, from: self.runtimeID)
        return outgoings.first.map { $0.0 }
    }

    // MARK: - Issues
    
    /// Append a user-facing issue for the entity representing a design object.
    ///
    /// Issues are non-fatal problems with user data. Systems should append
    /// issues here rather than throwing errors, allowing processing to continue
    /// and collect multiple issues.
    ///
    /// - Parameters:
    ///   - issue: The error/issue to append
    ///
    ///- Returns: `true` if the entity represents a design object, otherwise false.
    ///
    @discardableResult
    public func appendIssue(_ issue: Issue) -> Bool {
        guard let objectID = self.objectID else { return false }
        world.issues[objectID, default: []].append(issue)
        return true
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
    
    public subscript<T: Component>(_ type: T.Type, default defaultComponent: T) -> T {
        get {
            return component() ?? defaultComponent
        }
    }

    public var debugDescription: String {
        let compList = self.debugComponentNames().joined(separator: ",")
        return "E\(self.runtimeID)[\(compList)][ch:\(self.children.count)]"
    }


}
