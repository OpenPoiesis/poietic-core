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
    /// exists in the world's current frame.
    ///
    /// - SeeAlso: ``objectID``
    ///
    public var designObject: ObjectSnapshot? {
        guard let objectID = world.entityToObjectMap[runtimeID] else { return nil }
        return world.frame?[objectID]
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
    
    public func mutateOrSet<T: Component>(
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
    
    public var debugDescription: String {
        let compList = self.debugComponentNames().joined(separator: ",")
        return "E\(self.runtimeID)[\(compList)][ch:\(self.children.count)]"
    }

}
