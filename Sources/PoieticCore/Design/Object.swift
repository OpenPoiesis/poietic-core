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

/// A version of a design object.
///
/// Design objects are the main entities of the design. Each object can have
/// multiple versions and each version is called an _object snapshot_. In the
/// design process the object might exist in different states, based on its
/// mutability and validity. The ``ObjectSnapshot`` protocol provides unified
/// interface for all of those state representations.
///
/// The different representations that the object might be in are:
///
/// - ``StableObject``: Object that has been validated and can not be modified.
///   They are the items of a``StableFrame`` and can be shared by multiple frames.
/// - ``MutableObject``: Object of a temporary nature, that can be modified. The
///   Mutable object is then turned into a ``StableObject`` when valid.
/// - ``TransientObject``: Rather a wrapper over an object that belongs to a
///   ``TransientFrame``, it might refer to an original ``StableObject`` while
///   the object has not been modified or to a ``MutableObject`` once a
///   modification has been requested.
///
///
public protocol ObjectSnapshot: Identifiable where ID == ObjectID {
    /// Primary object identity.
    ///
    /// The object ID defines the main identity of an object within a design.
    /// One object can share multiple snapshots, which are identified by their
    /// ``snapshotID``.
    ///
    /// Objects within a ``Frame`` have unique object ``id``, however there
    /// might be multiple snapshots with the same ``id`` within the design.
    ///
    /// The ID is generated using ``Design/allocateID(required:)`` and is
    /// guaranteed to be unique within the design. If an object is coming from
    /// a foreign interface or from a storage, an explicit ID might be
    /// requested, however the programmer is responsible for checking its
    /// uniqueness within given context.
    ///
    /// - SeeAlso: ``snapshotID``,
    ///    ``Design/allocateID(proposed:)``,
    ///    ``Frame/object(_:)``,
    ///    ``Frame/contains(_:)``,
    ///
    var id: ObjectID { get }
    
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
    ///    ``Design/allocateID(required:)``
    ///    ``TransientFrame/mutate(_:)``
    ///
    var snapshotID: SnapshotID { get }
    
    
    /// Object type from the problem domain described by a metamodel.
    ///
    /// The ``ObjectType`` describes the typical object structure within a
    /// domain model. The domain model is described through ``Metamodel``.
    ///
    /// When object is validated and accepted by ``Design/accept(_:appendHistory:)``,
    /// the object attributes and their values must conform to the object type
    /// attributes.
    ///
    /// - SeeAlso:
    ///     ``ObjectType``, ``Metamodel``
    ///     ``Frame/filter(type:)``,
    ///     ``IsTypePredicate``
    ///
    var type: ObjectType { get }

    /// Structural role of the object within a design.
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
    var structure: StructuralComponent { get }
    var parent: ObjectID? { get }
    var children: ChildrenSet { get }
    var components: ComponentSet { get }
    
    var name: String? { get }
    
    subscript(attributeKey: String) -> Variant? { get }
    subscript<T>(componentType: T.Type) -> T? where T : Component { get }
}

extension ObjectSnapshot {
    /// Get object name if the object has an attribute `name`.
    ///
    /// This is provided for convenience.
    ///
    /// - Note: The `name` attribute must be either a string or an integer,
    ///   otherwise `nil` is returned.
    ///
    public var name: String? {
        guard let value = self["name"] else {
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
public final class StableObject: ObjectSnapshot, CustomStringConvertible {
    
    public let snapshotID: SnapshotID
    public let id: ObjectID
    public let type: ObjectType

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
    
    
    public let structure: StructuralComponent
    
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
    public let parent: ObjectID?

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
    public let children: ChildrenSet
    
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
                children: [ObjectID] = [],
                attributes: [String:Variant] = [:],
                components: [any Component] = []) {
        precondition(ReservedAttributeNames.allSatisfy({ attributes[$0] == nil}),
                     "The attributes must not contain any reserved attribute")
        
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.structure = structure
        self.parent = parent

        self.attributes = attributes
        self.components = ComponentSet(components)
        self.children = ChildrenSet(children)
    }
    
    convenience init(_ object: MutableObject) {
        self.init(id: object.id,
                  snapshotID: object.snapshotID,
                  type: object.type,
                  structure: object.structure,
                  parent: object.parent,
                  children: object.children.items,
                  attributes: object.attributes,
                  components: object.components.components)
    }

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
    
    @inlinable
    public var attributeKeys: [AttributeKey] {
        return attributes.keys.map { $0 }
    }

}

