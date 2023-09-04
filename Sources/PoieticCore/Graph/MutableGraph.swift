//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

/// Protocol
public protocol MutableGraph: Graph {
    /// Remove all nodes and edges from the graph.
    func removeAll()
    
    /// Add a node to the graph.
    ///
    func insert(_ node: Node)
    
    /// Add an edge to the graph.
    ///
    func insert(_ edge: Edge)
    
    /// Remove a node from the graph and return a list of edges that were
    /// removed together with the node.
    ///
    func remove(node nodeID: ObjectID)
    
    /// Remove an edge from the graph.
    ///
    func remove(edge edgeID: ObjectID)
    
    
    /// Convenience method to create a node without a name and without any
    /// components.
    ///
    /// - SeeAlso: ``createNode(_:name:components:)``
    ///
    @discardableResult
    func createNode(_ type: ObjectType) -> ObjectID

    // Object creation
    @discardableResult
    func createNode(_ type: ObjectType,
                    name: String?,
                    components: [Component]) -> ObjectID

    @discardableResult
    func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID,
                    components: [Component]) -> ObjectID
}

extension MutableGraph {
    public func removeAll() {
        for edge in edgeIDs {
            remove(edge: edge)
        }
        for node in nodeIDs {
            remove(node: node)
        }
    }
    
    public func createNode(_ type: ObjectType) -> ObjectID {
        return self.createNode(type, name: nil, components: [])
    }

    @discardableResult
    public func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID) -> ObjectID{

        return self.createEdge(type,
                              origin: origin,
                              target: target,
                              components: [])
    }

}


/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
public class MutableUnboundGraph: UnboundGraph, MutableGraph {
    // FIXME: IMPORTANT!: This is a quick hack due to some redesign.
    
    var mutableFrame: MutableFrame {
        self.frame as! MutableFrame
    }
    
    public func insert(_ node: Node) {
        self.mutableFrame.insert(node.snapshot)
    }
    
    public func insert(_ edge: Edge) {
        self.mutableFrame.insert(edge.snapshot)
    }
    // Object creation
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .edge,
                     "Trying to create an edge using a type '\(type.name)' that has a different structural type: \(type.structuralType)")
        precondition(frame.contains(origin),
                     "Trying to create an edge with unknown origin ID \(origin) in the frame")
        precondition(frame.contains(target),
                     "Trying to create an edge with unknown target ID \(target) in the frame")

        let snapshot = mutableFrame.memory.createSnapshot(
            type,
            components: components,
            structuralReferences: [origin, target],
            initialized: false
        )

        for componentType in type.components {
            if !snapshot.components.has(componentType) {
                snapshot.components.set(componentType.init())
            }
        }
        snapshot.makeInitialized()
        mutableFrame.insert(snapshot, owned: true)
        return snapshot.id
    }
   
    
    /// Creates a new node.
    ///
    /// - Parameters:
    ///     - type: Object type of the newly created node.
    ///     - name: Optional object name. See note below.
    ///     - components: List of components assigned with the node.
    ///
    /// If the object name is provided, then ``NameComponent`` added to the
    /// component list. If your metamodel does not use the ``NameComponent``,
    /// then you have to create the name using the name-bearing component
    /// manually.
    ///
    public func createNode(_ type: ObjectType,
                           name: String? = nil,
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .node,
                     "Trying to create a node using a type '\(type.name)' that has a different structural type: \(type.structuralType)")

        // TODO: This is not very clean: we create a template, then we derive the concrete object.
        // Frame is not aware of structural types, can only create plain objects.
        // See file Documentation/ObjectCreation.md for more discussion.
        let actualComponents: [any Component]
        
        if let name {
            actualComponents = [NameComponent(name: name)] + components
        }
        else {
            actualComponents = components
        }
        
        let snapshot = mutableFrame.memory.createSnapshot(
            type,
            components: actualComponents,
            initialized: false
        )

        for componentType in type.components {
            if !snapshot.components.has(componentType) {
                snapshot.components.set(componentType.init())
            }
        }
        snapshot.makeInitialized()
        mutableFrame.insert(snapshot, owned: true)
        return snapshot.id
    }

    public func remove(node nodeID: ObjectID) {
        self.mutableFrame.removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        self.mutableFrame.removeCascading(edgeID)
    }
}
