//
//  File.swift
//
//
//  Created by Stefan Urbanek on 2021/10/10.
//

/// An abstract class representing a version of an object in the database.
///
public class ObjectSnapshot: Identifiable, CustomStringConvertible {
    public typealias ID = ObjectID
    
    /// Unique identifier of the version snapshot within the database.
    public let snapshotID: SnapshotID
    
    /// Object identifier that groups all object's versions.
    ///
    public let id: ObjectID
    
    public var components: ComponentSet
    
    public let type: ObjectType?
    
    public var state: VersionState
    
    var structuralTypeName: String {
        return "object"
    }
    
    // TODO: Make this private. Use Holon.create() and Holon.connect()
    /// Create an empty object.
    ///
    /// If the ID is not provided, one will be assigned. The assigned ID is
    /// assumed to be unique for every object created without explicit ID,
    /// however it is not assumed to be unique with explicitly provided IDs.
    ///
    public init(id: ObjectID,
                snapshotID: SnapshotID,
                type: ObjectType? = nil,
                components: [any Component] = []) {
        self.id = id
        self.snapshotID = snapshotID
        self.components = ComponentSet(components)
        self.type = type
        self.state = .unstable
    }
    
    public convenience init(fromRecord record: ForeignRecord,
                            metamodel: Metamodel.Type,
                            components: [String:ForeignRecord]=[:]) throws {
        // TODO: Handle wrong IDs
        let id: ObjectID = try record.IDValue(for: "object_id")
        let snapshotID: SnapshotID = try record.IDValue(for: "snapshot_id")
        
        let type: ObjectType?
        
        if let typeName = try record.stringValueIfPresent(for: "type") {
            if let objectType = metamodel.objectType(name: typeName) {
                type = objectType
            }
            else {
                fatalError("Unknown object type: \(typeName)")
            }
        }
        else {
            type = nil
        }
        
        var componentInstances: [any Component] = []
        
        for (name, record) in components {
            let type: Component.Type = persistableComponent(name: name)!
            let component = try type.init(record: record)
            componentInstances.append(component)
        }

        self.init(id: id,
                  snapshotID: snapshotID,
                  type: type,
                  components: componentInstances)
    }
    
    /// Create a foreign record from the snapshot.
    ///
    public func foreignRecord() -> ForeignRecord {
        let record = ForeignRecord([
            "object_id": ForeignValue(id),
            "snapshot_id": ForeignValue(snapshotID),
            "structural_type": ForeignValue(structuralTypeName),
            "type": ForeignValue(type?.name ?? "none"),
        ])
        return record
    }
    
    open var description: String {
        let typeName = self.type?.name ?? "(untyped)"
        let selfName = String(describing: Swift.type(of: self))
        return "\(selfName)(id: \(id), ssid: \(snapshotID), type:\(typeName))"
    }
   
    open var prettyDescription: String {
        let typeName = self.type?.name ?? "(untyped)"
        let selfName = String(describing: Swift.type(of: self))

        return "\(id) \(selfName) \(typeName)"
    }
    
    func freeze() {
        assert(self.state != .frozen)
        self.state = .frozen
    }
    
    var structuralDependencies: [ObjectID] {
        return []
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
    
    
    public func attribute(forKey key: String) -> ForeignValue? {
        // FIXME: This needs attention. It was written hastily without deeper thought.
        let keyPath = key.split(separator: ".", maxSplits: 2)
        let componentName: String?
        let attributeName: String
        
        if keyPath.count == 1 {
            componentName = nil
            attributeName = String(keyPath[0])
        }
        else {
            componentName = String(keyPath[0])
            attributeName = String(keyPath[1])
        }
        
        if let componentName {
            guard let component = _component(named: componentName) else {
                fatalError("Unknown component: \(componentName)")
            }
            
            return component.attribute(forKey: attributeName)
        }
        else {
            switch attributeName {
            case "id": return ForeignValue(id)
            case "snapshot_id": return ForeignValue(snapshotID)
            case "type":
                if let type {
                    return ForeignValue(type.name)
                }
                else {
                    return ForeignValue("untyped")
                }
            case "structural_type": return ForeignValue(structuralTypeName)
            default: fatalError("Unknown attribute: \(attributeName)")
            }
        }
        
        
    }
    private func _component(named name: String) -> (any Component)? {
        return components.first { $0.componentName == name }
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
