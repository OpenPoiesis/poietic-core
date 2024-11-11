//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

/// Protocol
public protocol MutableGraph: Graph {
    // Object creation
    @discardableResult
    func createNode(_ type: ObjectType,
                    name: String?,
                    attributes: [String:Variant],
                    components: [Component]) -> ObjectID
    
    @discardableResult
    func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID,
                    attributes: [String:Variant],
                    components: [Component]) -> ObjectID

    /// Remove all nodes and edges from the graph.
    func removeAll()
    
    /// Remove a node from the graph and return a list of edges that were
    /// removed together with the node.
    ///
    func remove(node nodeID: ObjectID)
    
    /// Remove an edge from the graph.
    ///
    func remove(edge edgeID: ObjectID)
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
        return self.createNode(type, name: nil, attributes: [:], components: [])
    }

    @discardableResult
    public func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID) -> ObjectID{

        return self.createEdge(type,
                               origin: origin,
                               target: target,
                               attributes: [:],
                               components: [])
    }

}


/// Graph contained within a mutable frame where the references to the nodes and
/// edges are not directly bound and are resolved at the time of querying.
extension TransientFrame: MutableGraph {
    var mutableFrame: TransientFrame { self }
    
    // Object creation
    @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: ObjectID,
                           target: ObjectID,
                           attributes: [String:Variant] = [:],
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .edge,
                     "Trying to create an edge using a type '\(type.name)' that has a different structural type: \(type.structuralType)")
        precondition(contains(origin),
                     "Trying to create an edge with unknown origin ID \(origin) in the frame")
        precondition(contains(target),
                     "Trying to create an edge with unknown target ID \(target) in the frame")

        let snapshot = mutableFrame.create(
            type,
            structure: .edge(origin, target),
            attributes: attributes,
            components: components
        )
        
        return snapshot.id
    }
   
    
    /// Creates a new node.
    ///
    /// - Parameters:
    ///     - type: Object type of the newly created node.
    ///     - name: Optional object name. See note below.
    ///     - attributes: Dictionary of attributes to set.
    ///     - components: List of components assigned with the node.
    ///
    /// If the object name is provided, then attribute `name` of the
    /// object is set. Replaces `name` attribute in the `attributes` dictionary.
    ///
    @discardableResult
    public func createNode(_ type: ObjectType,
                           name: String? = nil,
                           attributes: [String:Variant] = [:],
                           components: [any Component] = []) -> ObjectID {
        precondition(type.structuralType == .node,
                     "Trying to create a node using a type '\(type.name)' that has a different structural type: \(type.structuralType)")

        var actualAttributes = attributes
        
        if let name {
            actualAttributes["name"] = Variant(name)
        }
        
        let snapshot = mutableFrame.create(
            type,
            attributes: actualAttributes,
            components: components
        )

        return snapshot.id
    }

    public func remove(node nodeID: ObjectID) {
        self.mutableFrame.removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        self.mutableFrame.removeCascading(edgeID)
    }
}
