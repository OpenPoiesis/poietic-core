//
//  MutableObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 10/11/2024.
//

// TODO: Find a better home
// TODO: Use some special pattern, such as "__" prefix or "%"
/// List of attribute names that are reserved and should not be used.
///
public let ReservedAttributeNames = [
    "id", "snapshot_id", "origin", "target", "type", "parent", "structure",
]


/// Transient object that can be modified.
///
/// Mutable objects are temporary and typically exist only during a change
/// transaction. New objects are created within a ``TransientFrame`` by ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``.
/// Mutable versions of existing stable objects are created with``TransientFrame/mutate(_:)``.
///
/// Mutable objects are converted to stable objects with ``TransientFrame/accept()``.
///
/// - SeeAlso: ``TransientFrame``
///
public class MutableObject: ObjectSnapshot {
    public let id: ObjectID
    public let snapshotID: ObjectID
    public let type: ObjectType
    public var structure: Structure
    public var attributes: [String:Variant]
    public var parent: ObjectID?
    public var children: ChildrenSet
    public var components: ComponentSet
    
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType,
                structure: Structure = .unstructured,
                parent: ObjectID? = nil,
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:],
                components: [any Component] = []) {
        precondition(ReservedAttributeNames.allSatisfy({ attributes[$0] == nil}),
                     "The attributes must not contain any reserved attribute")
        
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.structure = structure
        self.attributes = attributes
        self.components = ComponentSet(components)
        self.parent = parent
        self.children = ChildrenSet(children)
    }
    
    
    /// Get a value for an attribute.
    ///
    /// The function returns a foreign value for a given attribute from
    /// the components or for a special snapshot attribute.
    ///
    /// The special snapshot attributes are:
    /// - `"id"` – object ID of the snapshot
    /// - `"snapshotID"` – ID of object version snapshot
    /// - `"type"` – name of the object type, see ``ObjectType/name``
    /// - `"structure"` – name of the structural type of the object
    ///
    /// Other keys are searched in the list of object's components. The
    /// first value found in the list of the components is returned.
    ///
    /// - SeeAlso: ``InspectableComponent/attribute(forKey:)``
    ///
    @inlinable
    public func attribute(forKey key: String) -> Variant? {
        switch key {
        case "id": Variant(String(id))
        case "snapshot_id": Variant(String(snapshotID))
        case "type": Variant(type.name)
        case "structure": Variant(structure.type.rawValue)
        default: attributes[key]
        }
    }
    
    public var attributeKeys: [AttributeKey] {
        return Array(attributes.keys)
    }

    public subscript(key: String) -> Variant? {
        get {
            attribute(forKey: key)
        }
        set(value) {
            if let value {
                setAttribute(value: value, forKey: key)
            }
            else {
                removeAttribute(forKey: key)
            }
            
        }
    }
    
    /// Set an attribute value for given key.
    ///
    /// - Precondition: The attribute must not be a reserved attribute (``ObjectSnapshot/ReservedAttributeNames``).
    ///
    public func setAttribute(value: Variant, forKey key: String) {
        precondition(ReservedAttributeNames.firstIndex(of: "key") == nil,
                     "Trying to set a reserved read-only attribute '\(key)'")
        attributes[key] = value
    }
    
    public func removeAttribute(forKey key: String) {
        attributes[key] = nil
    }

    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return components[componentType]
        }
        set(component) {
            components[componentType] = component
        }
    }

}

// MARK: - Transient Object

/// A wrapper for for an object in a transient frame.
///
/// The transient object refers to one of two possible target objects: original
/// stable snapshot or a mutable snapshot in a ``TransientFrame``.
///
/// - SeeAlso: ``MutableObject``
///
public struct TransientObject: ObjectSnapshot {
    let frame: TransientFrame
    public let id: ObjectID

    public var snapshotID: SnapshotID { snapshot.snapshotID }
    public var type: ObjectType { snapshot.type }
    public var structure: Structure { snapshot.structure }
    public var parent: ObjectID? { snapshot.parent }
    public var children: ChildrenSet { snapshot.children }
    public var components: ComponentSet { snapshot.components }

    var snapshot: any ObjectSnapshot {
        guard let wrapped = frame.transientSnapshot(id) else {
            fatalError("Can not get transient snapshot \(id) in frame \(frame.id)")
        }
        return wrapped.unwrapped
    }
    
    public init(frame: TransientFrame, id: ObjectID) {
        self.frame = frame
        self.id = id
    }

    public subscript(key: String) -> (Variant)? {
        get {
            attribute(forKey: key)
        }
    }
    
    public func attribute(forKey key: String) -> Variant? {
        snapshot[key]
    }

    public var attributeKeys: [AttributeKey] {
        return Array(snapshot.attributeKeys)
    }
    
    

    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return snapshot[componentType]
        }
    }

}
