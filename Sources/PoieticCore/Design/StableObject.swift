//
//  DesignObject.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 11/11/2024.
//


@usableFromInline
package struct _ObjectBody {
    // Identity
    public let snapshotID: SnapshotID
    public let id: ObjectID
    public let type: ObjectType
    
    // State
    public var structure: Structure
    public var parent: ObjectID?
    public var children: ChildrenSet
    public var attributes: [String:Variant]
    
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType,
                structure: Structure,
                parent: ObjectID?,
                children: [ObjectID],
                attributes: [String:Variant]) {
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.structure = structure
        self.parent = parent

        self.attributes = attributes
        self.children = ChildrenSet(children)
    }
}

/// Version snapshot of a design object.
///
/// This is the primary design entity. Stable objects can be shared between
/// multiple frames.
///
/// Once created, stable object's design properties (attributes and structure)
/// can not be changed. Only changes that can be made to an object is to
/// add or remove runtime components.
///
/// ## Creation
///
/// To create an object and to include it in the design, the object's identity
/// needs to be assured. It can be either provided by the design, taken
/// from an external source or created in a custom way.
///
/// To create a new object with new identity the ``Design/allocateID(required:)``
/// is used first then passed to the ``init(id:snapshotID:type:structure:parent:children:attributes:components:)``.
/// Stable object then can be inserted in a ``TransientFrame``:
///
/// ```swift
/// let design: Design // Let's assume we have this
///
/// let snapshot = DesignObject(id: design.allocateID(),
///                             snapshotID: design.allocateID(),
///                             type: ObjectType.Node)
///
/// let frame design.createFrame()
/// frame.insert(snapshot)
/// ```
/// Another option is to create objects using ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
/// or to derive versions using ``TransientFrame/mutate(_:)`` then turn the
/// mutable objects into stable objects using ``TransientFrame/accept()``.
///
/// - SeeAlso: ``DesignFrame``, ``TransientFrame``, ``Design/accept(_:appendHistory:)``
///
public final class DesignObject: ObjectSnapshot, CustomStringConvertible {
    @usableFromInline
    let _body: _ObjectBody
    public var components: ComponentSet

    /// Create a stable object.
    ///
    /// - Parameters:
    ///     - id: Object identity - typical object reference, unique in a frame
    ///     - snapshotID: ID of this object version snapshot – unique in design
    ///     - type: Type of the object. Will be used to initialise components, see below.
    ///     - structure: Structural component of the object.
    ///     - children: Children of the object.
    ///     - attributes: Initial attributes of the newly created object.
    ///     - parent: ID of parent object in the object hierarchy.
    ///     - components: List of components to be added to the object.
    ///
    /// - SeeAlso: ``TransientFrame/insert(_:)``, ``TransientFrame/accept()``
    /// - Precondition: Attributes must not contain any reserved attribute
    ///   (_name_, _id_, _type_, _snapshot_id_, _structure_, _parent_, _children_)
    ///
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
    @inlinable public var structure: Structure { _body.structure }
    @inlinable public var parent: ObjectID? { _body.parent }
    @inlinable public var children: ChildrenSet { _body.children }
    @inlinable public var attributes: [String:Variant] { _body.attributes }

    /// Textual description of the object.
    ///
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        let attrs = self.type.attributes.map {
            ($0.name, self[$0.name] ?? "nil")
        }.map { "\($0.0)=\($0.1)"}
        .joined(separator: ",")
        return "\(structuralName)(id:\(id), sid:\(snapshotID), type:\(type.name), attrs:\(attrs)"
    }
    
    /// Prettier description of the object.
    ///
    public var prettyDescription: String {
        let name: String = self.name ?? "(unnamed)"
        return "\(id) {\(type.name), \(structure.description), \(name))}"
    }
    

    @inlinable
    public subscript(attributeName: String) -> (Variant)? {
        return attribute(forKey: attributeName)
    }
    
    /// Get or set a component of given type, if present.
    ///
    /// Setting a component that already exists in the list of components will
    /// replace the existing component.
    ///
    /// - SeeAlso: ``ComponentSet``
    ///
    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return components[componentType]
        }
        set(component) {
            components[componentType] = component
        }
    }
    
    
    /// Get a value for an attribute.
    ///
    /// The function returns a foreign value for a given attribute from
    /// the components or for a special snapshot attribute.
    ///
    /// The special snapshot attributes are:
    ///
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
        default: _body.attributes[key]
        }
    }
    
    @inlinable
    public var attributeKeys: [AttributeKey] {
        return _body.attributes.keys.map { $0 }
    }
}
