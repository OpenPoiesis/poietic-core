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
    @usableFromInline
    package var _body: _ObjectBody
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
        
        self._body = _ObjectBody(id: id,
                                 snapshotID: snapshotID,
                                 type: type,
                                 structure: structure,
                                 parent: parent,
                                 children: children,
                                 attributes: attributes)
        self.components = ComponentSet(components)
    }

    init(body: _ObjectBody, components: ComponentSet) {
        self._body = body
        self.components = components
    }
   
    @inlinable public var id: ObjectID { _body.id }
    @inlinable public var snapshotID: ObjectID { _body.snapshotID }
    @inlinable public var type: ObjectType { _body.type }
    @inlinable public var structure: Structure {
        get { _body.structure }
        set(structure) { _body.structure = structure }
        
    }
    @inlinable public var parent: ObjectID? {
        get { _body.parent }
        set(parent) { _body.parent = parent }
    }
    @inlinable public var children: ChildrenSet { _body.children }
    @inlinable public var attributes: [String:Variant] { _body.attributes }

    /// Get a value for an attribute.
    ///
    /// The function returns a foreign value for a given attribute from
    /// the components or for a special snapshot attribute.
    ///
    /// The special snapshot attributes are:
    /// - `"id"` – object ID of the snapshot
    /// - `"snapshot_id"` – ID of object version snapshot
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
        case "id": Variant(id.stringValue)
        case "snapshot_id": Variant(snapshotID.stringValue)
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
    /// - Precondition: The attribute must not be a reserved attribute (``ReservedAttributeNames``).
    ///
    public func setAttribute(value: Variant, forKey key: String) {
        precondition(ReservedAttributeNames.firstIndex(of: "key") == nil,
                     "Trying to set a reserved read-only attribute '\(key)'")
        _body.attributes[key] = value
    }
    
    public func removeAttribute(forKey key: String) {
        _body.attributes[key] = nil
    }

    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return components[componentType]
        }
        set(component) {
            components[componentType] = component
        }
    }
    public func removeChild(_ child: ObjectID) {
        _body.children.remove(child)
    }
    public func addChild(_ child: ObjectID) {
        _body.children.add(child)
    }


}
