//
//  ObjectSnapshot.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

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
/// Objects are being created using the object memory
/// ``ObjectMemory/createSnapshot(_:id:snapshotID:components:structure:initialized:)``.
/// If the ``id`` and ``snapshotID`` are not provided, then they are generated
/// using object memory's identity generator.
///
/// ```swift
/// // The memory and the frame is given
/// let memory: ObjectMemory
/// let frame: MutableFrame
///
/// // Create a new unstructured snapshot of type MyType (assuming the type exists)
/// let snapshot = memory.createSnapshot(MyType)
/// frame.insert(snapshot)
///
/// ```
///
/// - SeeAlso: ``Frame``, ``MutableFrame``
///
public final class ObjectSnapshot: Identifiable, CustomStringConvertible {
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
    /// When mutating an object with ``MutableFrame/mutableObject(_:)`` a new
    /// snapshot with new snapshot ID but the same object ID will be created.
    ///
    /// - SeeAlso: ``id``, ``MutableFrame/insert(_:owned:)``,
    ///    ``ObjectMemory/allocateID(proposed:)``
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
    /// When mutating an object with ``MutableFrame/mutableObject(_:)`` a new
    /// snapshot with new snapshot ID but the same object ID will be created.
    ///
    /// - SeeAlso: ``snapshotID``,
    ///   ``Frame/object(_:)``, ``Frame/contains(_:)``,
    ///    ``MutableFrame/mutableObject(_:)``,
    ///    ``ObjectMemory/allocateID(proposed:)``
    ///
    public let id: ObjectID
    
    /// List of components of the object.
    ///
    /// An object can have multiple components but only
    /// one component of a given type.
    ///
    /// Objects can be also queried based on whether they contain a given
    /// component type with ``Frame/filter(component:)``
    /// or using ``Frame/filter(_:)`` with ``HasComponentPredicate``.
    ///
    ///
    /// - SeeAlso: ``Component``, ``ObjectType``.
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
    /// or using ``Frame/filter(_:)`` with ``IsTypePredicate``.
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
    /// of the object within the memory.
    ///
    /// Objects can be either unstructured (``StructuralComponent/unstructured``)
    /// or have a special role in different views of the design, such as nodes
    /// and edges in a graph.
    ///
    /// Structural component also denotes which objects depend on the object.
    /// For example, if objects is an edge and any of it's ``StructuralComponent/edge(_:_:)``
    /// elements is removed from the memory, then the edge is removed as well.
    ///
    /// - SeeAlso: ``MutableFrame/removeCascading(_:)``, ``Graph``
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
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    ///
    public var parent: ObjectID? = nil {
        willSet {
            precondition(state.isMutable)
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
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
    ///
    ///
    public var children: ChildrenSet = ChildrenSet() {
        willSet {
            precondition(state.isMutable)
        }
    }
    
    /// Create an empty object.
    ///
    /// - Parameters:
    ///     - id: Object identity - typical object reference, unique in a frame
    ///     - snapshotID: ID of this object version snapshot – unique in memory
    ///     - type: Type of the object. Will be used to initialise components, see below.
    ///     - structure: Structural component of the object.
    ///     - components: List of components to be added to the object.
    ///
    /// If the list of components does not contain all the components required
    /// by the ``type``, then a component with default values will be created.
    ///
    /// The caller is responsible to finalise initialisation of the object using
    /// one of the initialisation methods or with ``markInitialized()`` before
    /// the snapshot can be inserted into a frame.
    ///
    /// - Returns: Snapshot that is marked as uninitialised.
    ///
    /// - SeeAlso: ``initialize(structure:)``, ``initialize(structure:record:)``,
    /// ``makeInitialized()``
    ///
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType,
                structure: StructuralComponent = .unstructured,
                components: [any Component] = []) {
        // TODO: Make creation private - only through the memory.
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.state = .transient
        self.structure = structure

        self.components = ComponentSet(components)

        // Add required components as described by the object type.
        //
        for componentType in type.components {
            guard !self.components.has(componentType) else {
                continue
            }
            let component = componentType.init()
            self.components.set(component)
        }
    }
    
    /// Create a foreign object from the snapshot.
    ///
    /// Use this method to create a representation of the snapshot that can be
    /// used in foreign interfaces - persisting, converting to other formats,
    /// sending over a network, etc.
    ///
    public func foreignObject() -> ForeignObject {
        let children = self.children.map { String($0) }
        let origin: String?
        let target: String?
        
        switch structure {
        case .unstructured, .node:
            origin = nil
            target = nil
        case let .edge(originID, targetID):
            origin = String(originID)
            target = String(targetID)
        }

        let foreign = ForeignObject(type: type.name,
                                    id: String(id),
                                    snapshotID: String(snapshotID),
                                    name: self.name,
                                    attributes: attributesAsForeignRecord(),
                                    origin: origin,
                                    target: target,
                                    children: children)

        return foreign
    }
    
    /// Create a foreign record for all snapshot's attributes.
    ///
    /// Attributes from all ``InspectableComponent`` components are included
    /// regardles whether the objects type advertises them or not.
    ///
    /// - SeeAlso: ``InspectableComponent/attributeKeys``, ``InspectableComponent/attribute(forKey:)``
    ///
    public func attributesAsForeignRecord() -> ForeignRecord {
        // Preserve all foreign attributes regardles whether they are advertised
        // by the type or not. This includes attributes from additional
        // components.
        //
        // TODO: Test this.
        var dict: [String: ForeignValue] = [:]
        for component in self.inspectableComponents {
            for key in component.attributeKeys {
                dict[key] = component.attribute(forKey: key)
            }
        }
        let record = ForeignRecord(dict)
        return record
    }
    /// Textual description of the object.
    ///
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        let attrs = self.type.attributes.map {
            ($0.name, attribute(forKey: $0.name) ?? "nil")
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
    

    /// Promote the object's state.
    ///
    /// The state must be a higher state than the current state of the object.
    /// The state order, from lowest to highest is: transient, stable,
    /// validated.
    ///
    /// Validated objects can no longer be changed. They make up ``StableFrame``s.
    ///
    public func promote(_ state: VersionState) {
        precondition(self.state < state,
                     "Can not promote from state \(self.state) to \(state)")
        self.state = state
    }
    
    public subscript(componentType: Component.Type) -> (Component)? {
        get {
            return components[componentType]
        }
        set(component) {
            precondition(state.isMutable)
            components[componentType] = component
        }
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
    public func attribute(forKey key: String) -> ForeignValue? {
        // TODO: This is asymmetrical with setAttribute, it should not be (that much)
        // TODO: Add tests
        switch key {
        case "id": return ForeignValue(id)
        case "snapshot_id": return ForeignValue(snapshotID)
        case "type":
            return ForeignValue(type.name)
        case "structure": return ForeignValue(structure.type.rawValue)
        default:
            // Find first component that has the value.
            for component in inspectableComponents {
                if let value = component.attribute(forKey: key){
                    return value
                }
            }
            return nil
        }
    }
    
    /// Set an attribute value for given key.
    ///
    /// The function fins the first component that contains the given attribute
    /// and tries to set the value. The provided foreign value must be
    /// convertible to the type of the attribute of the component.
    ///
    /// - Throws: ``AttributeError`` when the object has no attribute with
    ///   given key or when there is a mismatch of attribute type and the given
    ///   value type.
    ///
    /// - SeeAlso: ``InspectableComponent/setAttribute(value:forKey:)``
    ///
    public func setAttribute(value: ForeignValue, forKey key: String) throws {
        precondition(state.isMutable,
                     "Trying to set attribute on an immutable snapshot \(snapshotID)")
        
        guard let componentType = type.componentType(forAttribute: key) else {
            // TODO: What to do here? Fail? Throw?
            fatalError("Object type \(type.name) has no component with attribute \(key).")
        }
        
        guard let component = components[componentType] else {
            fatalError("Object \(debugID) is missing a required component: \(componentType.componentSchema.name)")
        }
        
        // TODO: The following does not work
        //        components[componentType]?.setAttribute(value: value, forKey: key)
        var inspectable = (component as! InspectableComponent)
        try inspectable.setAttribute(value: value, forKey: key)
        components.set(inspectable)
    }
    
    public var debugID: String {
        return "\(self.id).\(self.snapshotID)"
    }
    
    /// Get object name if it has a "name" attribute in any of the components.
    ///
    /// The method searches all the component for the `name` attribute and
    /// returns the first one it finds. If the object has multiple components
    /// with the `name` attribute, which it should not (see note below),
    /// which name is returned is unspecified.
    ///
    /// - Note: It is recommended that the name is stored in the
    ///   ``NameComponent``, however it is not required.
    ///
    /// - Note: Component attribute names share the same name-space, there
    ///   should not be multiple components with the same name. See
    ///   ``Component`` f
    ///
    /// - Returns: A name if found, otherwise `nil` if no component has `name`
    ///   attribute.
    ///
    /// - SeeAlso: ``NameComponent``
    ///
    public var name: String? {
        for component in inspectableComponents {
            if let name = component.attribute(forKey: "name") {
                return try? name.stringValue()
            }
        }
        return nil
    }
}
