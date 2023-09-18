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
    public let snapshotID: SnapshotID
    
    /// Object identifier that groups all object's versions.
    ///
    public let id: ObjectID
    
    /// List of components of the object.
    public var components: ComponentSet
    
    /// Object type within the problem domain.
    ///
    /// The object type is one of types from the design's ``Metamodel``.
    ///
    public let type: ObjectType
    
    public var state: VersionState
    
    public var structure: StructuralComponent
    
    // Hierarchy
    public var parent: ObjectID? = nil {
        willSet {
            precondition(state.isMutable)
        }
    }
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
    
    @available(*, deprecated, message: "Use alloc+initialize combo")
    public convenience init(fromRecord record: ForeignRecord,
                            metamodel: Metamodel.Type,
                            components: [String:ForeignRecord]=[:]) throws {
        // TODO: Handle wrong IDs
        let id: ObjectID = try record.IDValue(for: "object_id")
        let snapshotID: SnapshotID = try record.IDValue(for: "snapshot_id")
        
        let type: ObjectType
        
        if let typeName = try record.stringValueIfPresent(for: "type") {
            if let objectType = metamodel.objectType(name: typeName) {
                type = objectType
            }
            else {
                fatalError("Unknown object type: \(typeName)")
            }
        }
        else {
            fatalError("No object type provided in the record")
        }
        
        var componentInstances: [any Component] = []
        
        for (name, record) in components {
            let type: Component.Type = persistableComponent(name: name)!
            let component = try type.init(record: record)
            componentInstances.append(component)
        }
        
        let structuralType = try record.stringValueIfPresent(for: "structure") ?? "unstructured"
        let structure: StructuralComponent
        
        switch structuralType {
        case "unstructured":
            structure = .unstructured
        case "node":
            structure = .node
        case "edge":
            let origin: ObjectID = try record.IDValue(for: "origin")
            let target: ObjectID = try record.IDValue(for: "target")
            structure = .edge(origin, target)
        default:
            fatalError("Unknown structural type: '\(structuralType)'")
        }
        
        self.init(id: id,
                  snapshotID: snapshotID,
                  type: type,
                  structure: structure,
                  components: componentInstances)
    }
   
    /// Initialise the object.
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
    
    public var description: String {
        let structuralName: String = self.structure.type.rawValue
        return "\(structuralName)(id: \(id), ssid: \(snapshotID), type:\(type.name))"
    }
    
    public var prettyDescription: String {
        let name: String = self.name ?? "(unnamed)"
        return "\(id) {\(type.name), \(structure.description), \(name)}"
    }
    
    func makeInitialized() {
        precondition(self.state == .uninitialized)
        self.state = .transient
    }
    
    func freeze() {
        precondition(self.state != .frozen)
        self.state = .frozen
    }
    
    /// List of objects that this object depends on. If one of the objects from
    /// the list is removed from the frame, this object must be removed as well.
    ///
    var structuralDependencies: [ObjectID] {
        switch structure {
        case .unstructured, .node: []
        case .edge(let origin, let target): [origin, target]
        }
    }
    
    /// - Note: Subclasses are expected to override this method.
    public func derive(snapshotID: SnapshotID,
                       objectID: ObjectID? = nil) -> ObjectSnapshot {
        return ObjectSnapshot(id: objectID ?? self.id,
                              snapshotID: snapshotID,
                              type: self.type,
                              components: components.components)
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
            return component.attribute(forKey: key)
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
        
        guard var component = components[componentType] else {
            fatalError("Object \(debugID) is missing a required component: \(componentType.componentDescription.name)")
        }
        
        try component.setAttribute(value: value, forKey: key)
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
        for component in components {
            if let name = component.attribute(forKey: "name") {
                return try? name.stringValue()
            }
        }
        return nil
    }
}
