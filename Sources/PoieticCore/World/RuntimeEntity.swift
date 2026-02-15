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
        world.components[runtimeID]?.has(type) ?? false
    }

    /// Get a component for a runtime object
    ///
    /// - Parameters:
    ///   - runtimeID: Runtime ID of an object or an ephemeral entity.
    /// - Returns: The component if it exists, otherwise nil
    ///
    public func component<T: Component>() -> T? {
        world.components[runtimeID]?[T.self]
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
        // TODO: Check whether the object exists
        world.components[runtimeID, default: ComponentSet()].set(component)
    }
    
    /// Remove a component from an object
    ///
    /// - Parameters:
    ///   - type: The component type to remove
    ///   - runtimeID: The object ID
    ///
    public func removeComponent<T: Component>(_ type: T.Type) {
        // TODO: Check whether the object exists
        world.components[runtimeID]?.remove(type)
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
    /// // Mutate in place (for value types, creates copy, mutates, sets back)
    /// entity[Position.self]?.x += 10  // Works but creates copy!
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
