//
//  ObjectSnapshot.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

/// A class representing a version of an object in the database.
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
    /// - SeeAlso: ``Component``, ``ObjectType``.
    ///
    public var components: ComponentSet
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
    /// - SeeAlso: ``children``,
    /// ``MutableFrame/addChild(_:to:)``,
    /// ``MutableFrame/removeChild(_:from:)``,
    /// ``MutableFrame/removeFromParent(_:)``,
    /// ``MutableFrame/removeCascading(_:)``.
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
        self.id = id
        self.snapshotID = snapshotID
        self.type = type
        self.state = .uninitialized
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
    
    /// Initialise the object.
    ///
    /// The object will be initialised with given structure and marked as
    /// _transient_ (``VersionState/transient``), that means the object
    /// can be used in frames.
    ///
    /// - SeeAlso: ``VersionState``
    ///
    @discardableResult
    public func initialize(structure: StructuralComponent = .unstructured) -> ObjectSnapshot {
        precondition(self.state == .uninitialized,
                     "Trying to initialize already initialized object \(self.debugID)")

        self.structure = structure
        self.state = .transient
        return self
    }

    /// Initialise the object using a foreign record.
    ///
    /// The object will be initialised with given structure and attributes
    /// will be populated with values provided by the foreign record.
    /// Finally the object will be marked as
    /// _transient_ (``VersionState/transient``), that means the object
    /// can be used in frames.
    ///
    /// - SeeAlso: ``VersionState``
    ///
    @discardableResult
    public func initialize(structure: StructuralComponent = .unstructured,
                           record: ForeignRecord) throws -> ObjectSnapshot {
        precondition(self.state == .uninitialized,
                     "Trying to initialize already initialized object \(self.debugID)")

        for key in record.allKeys {
            try self.setAttribute(value: record[key]!, forKey: key)
        }
        self.structure = structure
        self.state = .transient
        return self
    }

    /// Create a foreign record from the snapshot.
    ///
    /// Use this method to create a representation of the snapshot that can be
    /// used in foreign interfaces - persisting, converting to other formats,
    /// sending over a network, etc.
    ///
    public func foreignRecord() -> ForeignRecord {
        var dict: [String:ForeignValue] = [
            "object_id": ForeignValue(id),
            "snapshot_id": ForeignValue(snapshotID),
            "structure": ForeignValue(structure.type.rawValue),
            "type": ForeignValue(type.name),
        ]
        
        switch structure {
        case .edge(let origin, let target):
            dict["origin"] = ForeignValue(origin)
            dict["target"] = ForeignValue(target)
        default:
            // Do nothing
            _ = 0
        }
        
        return ForeignRecord(dict)
    }
    
    /// Textual description of the object.
    ///
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        return "\(structuralName)(id: \(id), ssid: \(snapshotID), type:\(type.name))"
    }
    
    /// Prettier description of the object.
    ///
    public var prettyDescription: String {
        let name: String = self.name ?? "(unnamed)"
        return "\(id) {\(type.name), \(structure.description), \(name)}"
    }
    
    /// Mark the object as initialized.
    ///
    /// Frames can contain only initialised objects.
    ///
    /// - SeeAlso: ``ObjectMemory/deriveFrame(original:id:)``
    ///
    public func makeInitialized() {
        precondition(self.state == .uninitialized)
        self.state = .transient
    }
    
    /// Make the object immutable.
    ///
    /// Frozen objects can no longer be changed. They make up ``StableFrame``s.
    ///
    func freeze() {
        precondition(self.state != .frozen)
        self.state = .frozen
    }
    
    /// List of objects that this object depends on. If one of the objects from
    /// the list is removed from the frame, this object must be removed as well.
    ///
    /// - SeeAlso: ``MutableFrame/removeCascading(_:)``.
    ///
    var structuralDependencies: [ObjectID] {
        switch structure {
        case .unstructured, .node: []
        case .edge(let origin, let target): [origin, target]
        }
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
    
    public subscript<T>(componentType: T.Type) -> T? where T : Component {
        get {
            return components[componentType]
        }
        set(component) {
            precondition(state.isMutable)
            components[componentType] = component
        }
    }
    
    
    // TODO: Add tests
    public func attribute(forKey key: String) -> ForeignValue? {
        // FIXME: This needs attention. It was written hastily without deeper thought.
        // TODO: This is asymmetrical with setAttribute, it should not be (that much)
        // TODO: Add structural component keys here
        switch key {
        case "id": return ForeignValue(id)
        case "snapshot_id": return ForeignValue(snapshotID)
        case "type":
            return ForeignValue(type.name)
        case "structure": return ForeignValue(structure.type.rawValue)
        default:
            guard let componentType = type.componentType(forAttribute: key) else {
                // TODO: What to do here? Fail? Throw?
                return nil
                //                fatalError("Object type \(type.name) has no component with attribute \(key).")
            }
            
            guard let component = components[componentType] else {
                fatalError("Object \(debugID) is missing a required component: \(componentType.componentDescription.name)")
            }
            return (component as! InspectableComponent).attribute(forKey: key)
        }
    }
    
    // TODO: Add tests
    public func setAttribute(value: ForeignValue, forKey key: String) throws {
        precondition(state.isMutable,
                     "Trying to set attribute on an immutable snapshot \(snapshotID)")
        
        guard let componentType = type.componentType(forAttribute: key) else {
            // TODO: What to do here? Fail? Throw?
            fatalError("Object type \(type.name) has no component with attribute \(key).")
        }
        
        guard let component = components[componentType] else {
            fatalError("Object \(debugID) is missing a required component: \(componentType.componentDescription.name)")
        }
        var inspectable = (component as! InspectableComponent)
        try inspectable.setAttribute(value: value, forKey: key)
        components.set(component)
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
