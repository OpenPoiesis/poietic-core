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
    
    open var description: String {
        return "Object(id: \(idDebugString))"
    }
    
    func freeze() {
        assert(self.state != .frozen)
        self.state = .frozen
    }
    
    /// String representing the object's ID for debugging purposes - either the
    /// object ID or ObjectIdentifier of the object
    public var idDebugString: String {
        // TODO: This method is no longer needed
        return String(id)
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
