//
//  ObjectSnapshot.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

public typealias ID = UInt64

/// Identifier of a design objects.
///
/// The object ID is unique within the frame containing the object.
/// There might be multiple object snapshots representing the same object
/// and therefore have the same object ID.
///
/// - SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``
///
public typealias ObjectID = ID

/// Identifier of a design object version.
///
/// The snapshot ID is unique within a design containing the snapshot.
///
/// SeeAlso: ``ObjectSnapshot``, ``Design``,
///     ``Design/allocateID(required:)``, ``TransientFrame/mutableObject(_:)``
///
public typealias SnapshotID = ID

/// Identifier of a version frame.
///
/// Each frame in a design has an unique frame ID.
///
/// - SeeAlso: ``Frame``, ``Design/createFrame(id:)``, ``Design/deriveFrame(original:id:)``
///
public typealias FrameID = ID

/// Representation of a design object's version.
///
/// All design objects are represented by one or more object snapshots. The
/// design object is defined by the object ``id`` and its version is defined by
/// ``snapshotID``. Object snapshots with the same ``id`` represent different
/// versions of the same design object.
///
/// Each design object belongs to one or multiple version frames (``Frame``).
/// Each frame can contain only one snapshot of the same object.
///
///
/// ## Creation
///
/// Objects are typically being created using a dedicated _Design_ method
/// ``TransientFrame/create(_:id:snapshotID:structure:parent:attributes:components:)``.
/// If the ``id`` and ``snapshotID`` are not provided, then they are generated
/// by the design ID generation.
///
/// ```swift
/// // The design and the frame is given
/// let design: Design
/// let frame: TransientFrame = design.createFrame()
///
/// // Create a new Note object.
/// let object = frame.create(ObjectType.Note)
///
/// ```
///
/// - SeeAlso: ``Frame``, ``TransientFrame``
///
public final class ObjectSnapshot: Identifiable, CustomStringConvertible, MutableKeyedAttributes {
    public static let ReservedAttributeNames = [
        "id",
        "snapshot_id",
        "origin",
        "target",
        "type",
        "parent",

        "structure",
    ]
    
    public typealias ID = ObjectID
    
    /// Unique identifier of the version snapshot within the database.
    ///
    /// The `snapshotID` is unique in the whole design.
    ///
    /// One typically does not use the snapshot ID as it refers to object's
    /// particular version. Through the design the object's ``id`` is used as
    /// a logical reference to an object where the concrete version is used
    /// within the context of a frame.
    ///
    /// The snapshot ID is preserved during persistence. However, it is not
    /// necessary to be provided when importing object from foreign interfaces
    /// which are dealing with only single version frame.
    ///
    /// When mutating an object with ``TransientFrame/mutableObject(_:)`` a new
    /// snapshot with new snapshot ID but the same object ID will be created.
    ///
    /// - SeeAlso: ``id``, ``TransientFrame/insert(_:)``,
    ///    ``Design/allocateID(required:)``
    ///
    public let snapshotID: SnapshotID
    
    /// Object identity.
    ///
    /// The object ID defines the main identity of an object. An object might
    /// have multiple version snapshots which are identified by ``snapshotID``.
    /// Snapshots sharing the same object ID are different versions of the same
    /// object. Typically only snapshots from within the same frame are
    /// considered.
    ///
    /// The object ID is preserved during persistence.
    ///
    /// When mutating an object with ``TransientFrame/mutableObject(_:)`` a new
    /// snapshot with new snapshot ID but the same object ID will be created.
    ///
    /// - SeeAlso: ``snapshotID``,
    ///   ``Frame/object(_:)``, ``Frame/contains(_:)``,
    ///    ``TransientFrame/mutableObject(_:)``,
    ///    ``Design/allocateID(proposed:)``
    ///
    public let id: ObjectID
    
    /// Object attributes.
    ///
    public private(set) var attributes: [String:Variant]
    
    /// List of run-time components of the object.
    ///
    /// An object can have multiple runtime components but only one component
    /// of a given type. Components are used to store custom information
    /// during runtime. The components are not persisted.
    ///
    /// - SeeAlso: ``Component``.
    ///
    public var components: ComponentSet
    
    /// List of components where their attributes can be retrieved
    /// or set by their names.
    ///
    public var inspectableComponents: [any InspectableComponent] {
        components.compactMap {
            $0 as? InspectableComponent
        }
    }
    
    /// Object type within the problem domain.
    ///
    /// The ``ObjectType`` describes the typical object structure within a
    /// domain model. The domain model is described through ``Metamodel``.
    ///
    /// Object type is also used in querying of objects using ``Frame/filter(type:)-3zj9k``
    /// or using ``Frame/filter(_:)-50lwx`` with ``IsTypePredicate``.
    ///
    /// - SeeAlso: ``ObjectType``, ``Metamodel``
    ///
    public let type: ObjectType
    
    /// State in which the object is in.
    ///
    /// Denotes whether the object can be mutated and how it can be used in
    /// frames.
    ///
    public var state: VersionState
    
    /// Variable denoting the structural property or rather structural role
    /// of the object within a design.
    ///
    /// Objects can be either unstructured (``StructuralComponent/unstructured``)
    /// or have a special role in different views of the design, such as nodes
    /// and edges in a graph.
    ///
    /// Structural component also denotes which objects depend on the object.
    /// For example, if objects is an edge and any of it's ``StructuralComponent/edge(_:_:)``
    /// elements is removed from a design, then the edge is removed as well.
    ///
    /// - SeeAlso: ``TransientFrame/removeCascading(_:)``, ``Graph``
    ///
    public var structure: StructuralComponent
    
    // Hierarchy
    /// Object's parent – denotes hierarchical organisation of objects.
    ///
    /// You typically never have to set the parent property. It is being set
    /// by one of the mutable frame's methods (see below).
    ///
    /// Another way of specifying structural relationship of objects besides
    /// hierarchy is with the ``structure``.
    ///
    /// - SeeAlso: ``children``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    public var parent: ObjectID? = nil {
        willSet {
            precondition(state == .transient)
        }
    }

    /// List of object's children.
    ///
    /// Children are part of the hierarchical structure of objects. When
    /// an object is removed from a frame, all its children are removed
    /// with it, together with all dependencies.
    ///
    /// You typically never have to set the children set through this
    /// property. It is being set by one of the mutable frame's methods
    /// (see below).
    ///
    /// Another way of specifying structural relationship of objects besides
    /// hierarchy is with the ``structure``.
    ///
    /// - SeeAlso: ``parent``,
    /// ``TransientFrame/addChild(_:to:)``,
    /// ``TransientFrame/removeChild(_:from:)``,
    /// ``TransientFrame/removeFromParent(_:)``,
    /// ``TransientFrame/removeCascading(_:)``.
    ///
    ///
    public var children: ChildrenSet = ChildrenSet() {
        willSet {
            precondition(state == .transient)
        }
    }
    
    /// Create an empty object.
    ///
    /// - Parameters:
    ///     - id: Object identity - typical object reference, unique in a frame
    ///     - snapshotID: ID of this object version snapshot – unique in design
    ///     - type: Type of the object. Will be used to initialise components, see below.
    ///     - structure: Structural component of the object.
    ///     - attributes: Initial attributes of the newly created object.
    ///     - parent: ID of parent object in the object hierarchy.
    ///     - components: List of components to be added to the object.
    ///
    /// If the list of components does not contain all the components required
    /// by the ``type``, then a component with default values will be created.
    ///
    /// - Precondition: Attributes must not contain any reserved attribute.
    ///
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType,
                structure: StructuralComponent = .unstructured,
                parent: ObjectID? = nil,
                attributes: [String:Variant] = [:],
                components: [any Component] = []) {
        precondition(ObjectSnapshot.ReservedAttributeNames.allSatisfy({ attributes[$0] == nil}),
                     "The attributes must not contain any reserved attribute")
        
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.state = .transient
        self.structure = structure
        self.parent = parent

        self.attributes = attributes
        self.components = ComponentSet(components)
        self.state = .transient
    }
   
    /// Textual description of the object.
    ///
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        let attrs = self.type.attributes.map {
            ($0.name, self[$0.name] ?? "nil")
        }.map { "\($0.0)=\($0.1)"}
        .joined(separator: ",")
        return "\(structuralName)(id:\(id), sid:\(snapshotID), type:\(type.name), attrs:\(attrs), state: \(state)"
    }
    
    /// Prettier description of the object.
    ///
    public var prettyDescription: String {
        let name: String = self.name ?? "(unnamed)"
        return "\(id) {\(type.name), \(structure.description), \(name))}"
    }
    

    /// Promote the object's state.
    ///
    /// The state must be a higher state than the current state of the object.
    /// The state order, from lowest to highest is: transient, stable,
    /// validated.
    ///
    /// Validated objects can no longer be changed. They make up ``StableFrame``s.
    ///
    @inlinable
    public func promote(_ state: VersionState) {
        precondition(self.state < state,
                     "Can not promote from state \(self.state) to \(state)")
        self.state = state
    }
    
    @inlinable
    public subscript(attributeName: String) -> (Variant)? {
        get {
            return attribute(forKey: attributeName)
        }
        set(value) {
            if let value {
                setAttribute(value: value, forKey: attributeName)
            }
            else {
                removeAttribute(forKey: attributeName)
            }
        }
    }
    
    public func removeAttribute(forKey key: String) {
        precondition(state == .transient)
        attributes[key] = nil
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
            precondition(state.isMutable,
                         "Trying to set a component of an immutable object (id: \(self.id), sid: \(self.snapshotID))")
            components[componentType] = component
        }
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
    
    /// Set an attribute value for given key.
    ///
    /// - Precondition: The attribute must not be a reserved attribute (``ObjectSnapshot/ReservedAttributeNames``).
    ///
    public func setAttribute(value: Variant, forKey key: String) {
        precondition(state == .transient,
                     "Trying to set attribute on non-transient snapshot \(snapshotID)")
        precondition(ObjectSnapshot.ReservedAttributeNames.firstIndex(of: "key") == nil,
                     "Trying to set a reserved read-only attribute '\(key)'")
        attributes[key] = value
    }
    
    @inlinable
    public var attributeKeys: [AttributeKey] {
        return type.attributeKeys
    }

    public var debugID: String {
        return "\(self.id).\(self.snapshotID)"
    }
    
    /// Get object name if the object has an attribute `name`.
    ///
    /// This is provided for convenience.
    ///
    /// - Note: The `name` attribute must be either a string or an integer,
    ///   otherwise `nil` is returned.
    ///
    public var name: String? {
        guard let value = attributes["name"] else {
            return nil
        }
        guard case .atom(let atom) = value else {
            return nil
        }

        switch atom {
        case .string(let name): return name
        case .int(let name): return String(name)
        default: return nil
        }
    }
}

