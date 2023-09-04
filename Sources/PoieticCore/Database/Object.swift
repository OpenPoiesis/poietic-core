//
//  File.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

/// An abstract class representing a version of an object in the database.
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
    
    public var structuralTypeName: String {
        return "object"
    }
    
    public let structure: StructuralComponent
    
    // TODO: Make this private. Use Holon.create() and Holon.connect()
    /// Create an empty object.
    ///
    /// If the ID is not provided, one will be assigned. The assigned ID is
    /// assumed to be unique for every object created without explicit ID,
    /// however it is not assumed to be unique with explicitly provided IDs.
    ///
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType,
                structure: StructuralComponent = .unstructured,
                components: [any Component] = []) {
        self.id = id
        self.snapshotID = snapshotID
        self.components = ComponentSet(components)
        self.type = type
        self.state = .uninitialized
        self.structure = structure
    }
    
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
        let structuralName: String = self.structure.type.rawValue

        return "\(id) \(structuralName) \(type.name)"
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
        // TODO: This is asymmetric with setAttribute, it should not be (that much)
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
                fatalError("Object \(composedIDString) is missing a required component: \(componentType.componentDescription.name)")
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
            fatalError("Object \(composedIDString) is missing a required component: \(componentType.componentDescription.name)")
        }

        try component.setAttribute(value: value, forKey: key)
        components.set(component)
    }

    
    public var composedIDString: String {
        // FIXME: Still needed?
        return "\(self.id).\(self.snapshotID)"
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


/// A set of nodes and edges.
///
//public struct GraphObjectSet: Collection {
//    // TODO: This needs attention
//    public typealias Index = Array<Object>.Index
//    public typealias Element = Object
//    public let objects: [Object]
//    
//    public init(nodes: [Node] = [], edges: [Edge] = []) {
//        self.nodes = nodes
//        self.edges = edges
//    }
//    
//    public var startIndex: Index { return edges.startIndex }
//    public var endIndex: Index { return edges.endIndex }
//
//    
//}
