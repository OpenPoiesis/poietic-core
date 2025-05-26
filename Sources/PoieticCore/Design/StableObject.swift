//
//  ObjectSnapshot.swift
//  poietic-core
//
//  Created by Stefan Urbanek on 11/11/2024.
//

public final class LogicalObject: CustomStringConvertible, Identifiable {
    public let id: EntityID
    
    public init(id: EntityID) {
        self.id = id
    }
    
    public var description: String { "object(\(id)" }
}

// FIXME: [WIP] Update documentation
/// Version snapshot of a design object.
///
/// Immutable, point-in-time capture of an object's state.
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
/// To create a new object, use the ``TransientFrame/create(_:id:snapshotID:structure:parent:children:attributes:components:)``
/// method:
///
/// ```swift
/// let design: Design // Let's assume we have this
/// let trans = design.createFrame()
/// let object = trans.create(MyObjectType)
/// // ... Modify the object here ...
/// // ... Add more objects...
/// try design.accept(trans)
/// ```
/// - SeeAlso: ``DesignFrame``, ``TransientFrame``, ``Design/accept(_:appendHistory:)``, ``Design/identityManager``
///
public final class ObjectSnapshot: CustomStringConvertible, Identifiable, ObjectProtocol {
    /// Unique identifier of the object version snapshot within the design.
    ///
    /// The ``snapshotID`` represents a concrete version of an object. An
    /// object can have multiple versions, which all share the same identity
    /// of object ``id``.
    ///
    /// Typically when working with the design and design frames, one does not
    /// need to use the ``snapshotID``. It is used only when considering
    /// different versions of objects.
    ///
    /// When an object is mutated with ``TransientFrame/mutate(_:)``, the object
    /// ``id`` is preserved, but a new the ``snapshotID`` is generated.
    ///
    /// - SeeAlso: ``id``,
    ///    ``TransientFrame/mutate(_:)``
    ///
    public let id: EntityID

    @usableFromInline
    let _body: ObjectBody
    @inlinable public var objectID: ObjectID { _body.id }
    @inlinable public var snapshotID: EntityID { self.id }
    @inlinable public var type: ObjectType { _body.type }
    @inlinable public var structure: Structure { _body.structure }
    @inlinable public var parent: ObjectID? { _body.parent }
    @inlinable public var children: ChildrenSet { _body.children }
    @inlinable public var attributes: [String:Variant] { _body.attributes }

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
    /// - SeeAlso: ``TransientObject``
    /// - Precondition: Attributes must not contain any reserved attribute
    ///   (_name_, _id_, _type_, _snapshot_id_, _structure_, _parent_, _children_)
    ///
    public init(type: ObjectType,
                snapshotID: EntityID,
                objectID: ObjectID,
                structure: Structure = .unstructured,
                parent: ObjectID? = nil,
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:],
                components: [any Component] = []) {

        self.id = snapshotID
        self._body = ObjectBody(id: objectID,
                                 type: type,
                                 structure: structure,
                                 parent: parent,
                                 children: children,
                                 attributes: attributes)
        self.components = ComponentSet(components)
    }
    
    init(id: EntityID, body: ObjectBody, components: ComponentSet) {
        self.id = id
        self._body = body
        self.components = components
    }
    
    /// Textual description of the object.
    ///
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        let attrs = self.type.attributes.map {
            ($0.name, self[$0.name] ?? "nil")
        }.map { "\($0.0)=\($0.1)"}
        .joined(separator: ",")
        return "\(structuralName)(oid:\(_body.id), sid:\(self.id), type:\(type.name), attrs:\(attrs)"
    }
    
    /// Prettier description of the object.
    ///
    public var prettyDescription: String {
        let name: String = name ?? "(unnamed)"
        return "\(_body.id) {\(type.name), \(structure.description), \(name))}"
    }
    
    @inlinable
    public subscript(attributeName: String) -> (Variant)? {
        _body.attributes[attributeName]
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
}
