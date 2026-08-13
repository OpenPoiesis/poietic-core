//
//  ObjectSnapshot.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 11/11/2024.
//

import Collections

public final class LogicalObject: CustomStringConvertible, Identifiable, RCTableElement {
    public let id: ObjectID
    public var storageKey: ObjectSnapshotID { id }

    public init(id: ObjectID) {
        self.id = id
    }
    
    public var description: String { "object(\(id)" }
}

/// Version snapshot of a design object.
///
/// Immutable, point-in-time capture of an object's state.
///
/// This is the primary design entity. Stable objects can be shared between
/// multiple planes.
///
/// Once created, stable object's design properties (attributes and topology)
/// can not be changed. Only changes that can be made to an object is to
/// add or remove runtime components.
///
/// ## Creation
///
/// To create an object and to include it in the design, the object's identity
/// needs to be assured. It can be either provided by the design, taken
/// from an external source or created in a custom way.
///
/// To create a new object, use the ``TransientPlane/create(_:objectID:snapshotID:topology:parent:children:attributes:)
/// method:
///
/// ```swift
/// let design: Design // Let's assume we have this
/// let trans = design.createPlane()
/// let object = trans.create(MyObjectType)
/// // ... Modify the object here ...
/// // ... Add more objects...
/// try design.accept(trans)
/// ```
/// - SeeAlso: ``DesignPlane``, ``TransientPlane``, ``Design/accept(_:appendHistory:)``, ``Design/identityManager``
///
public final class ObjectSnapshot: CustomStringConvertible, Identifiable, ObjectProtocol, RCTableElement {
    /// Unique identifier of the object version snapshot within the design.
    ///
    /// The ``snapshotID`` represents a concrete version of an object. An
    /// object can have multiple versions, which all share the same identity
    /// of object ``id``.
    ///
    /// Typically when working with the design and design planes, one does not
    /// need to use the ``snapshotID``. It is used only when considering
    /// different versions of objects.
    ///
    /// When an object is mutated with ``TransientPlane/mutate(_:)``, the object
    /// ``id`` is preserved, but a new the ``snapshotID`` is generated.
    ///
    /// - SeeAlso: ``id``,
    ///    ``TransientPlane/mutate(_:)``
    ///
    public let id: ObjectSnapshotID

    public var storageKey: ObjectSnapshotID { id }
    
    @usableFromInline
    let _body: ObjectBody
    @inlinable public var objectID: ObjectID { _body.id }
    @inlinable public var snapshotID: ObjectSnapshotID { self.id }
    @inlinable public var type: ObjectType { _body.type }
    @inlinable public var topology: Topology { _body.topology }
    @inlinable public var parent: ObjectID? { _body.parent }
    @inlinable public var children: OrderedSet<ObjectID> { _body.children }
    @inlinable public var attributes: [String:Variant] { _body.attributes }

    /// Create a stable object.
    ///
    /// - Parameters:
    ///     - objectID: Object identity - typical object reference, unique in a plane
    ///     - snapshotID: ID of this object version snapshot – unique in design
    ///     - type: Type of the object. Will be used to initialise components, see below.
    ///     - topology: Topological property of the object which might refer to other objects.
    ///     - children: Children of the object.
    ///     - attributes: Initial attributes of the newly created object.
    ///     - parent: ID of parent object in the object hierarchy.
    ///
    /// - SeeAlso: ``TransientObject``
    /// - Precondition: Attributes must not contain any reserved attribute
    ///   (_name_, _id_, _type_, _snapshot_id_, _topology_, _parent_, _children_)
    ///
    public init(type: ObjectType,
                snapshotID: ObjectSnapshotID,
                objectID: ObjectID,
                topology: Topology = .unstructured,
                parent: ObjectID? = nil,
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:]) {

        self.id = snapshotID
        self._body = ObjectBody(id: objectID,
                                 type: type,
                                 topology: topology,
                                 parent: parent,
                                 children: children,
                                 attributes: attributes)
    }
    
    init(id: ObjectSnapshotID, body: ObjectBody) {
        self.id = id
        self._body = body
    }
    
    /// Textual description of the object.
    ///
    public var description: String {
        let topologyName: String = self.topology.type.rawValue
        let attrs = self.attributes.map { (name, value) in
            "\(name)=\(value)"
        }.joined(separator: ",")
        return "\(topologyName)(oid:\(_body.id), sid:\(self.id), type:\(type.name), attrs:\(attrs))"
    }
    
    /// Prettier description of the object.
    ///
    public var prettyDescription: String {
        let name: String = name ?? "(unnamed)"
        return "\(_body.id) {\(type.name), \(topology.description), \(name))}"
    }
    
    @inlinable
    public subscript(attributeName: String) -> (Variant)? {
        _body.attributes[attributeName]
    }
}
