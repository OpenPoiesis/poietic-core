//
//  MutableGraph.swift
//  
//
//  Created by Stefan Urbanek on 21/08/2023.
//

/// Protocol
public protocol MutableGraph: ObjectGraph {
    // FIXME: [WIP] Remove component from the convenience methods below
    // Object creation
    @discardableResult
    func createNode(_ type: ObjectType,
                    name: String?,
                    attributes: [String:Variant],
                    components: [Component]) -> MutableObject
    
    @discardableResult
    func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID,
                    attributes: [String:Variant],
                    components: [Component]) -> MutableObject

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
    
    public func createNode(_ type: ObjectType) -> MutableObject {
        return self.createNode(type, name: nil, attributes: [:], components: [])
    }

    @discardableResult
    public func createEdge(_ type: ObjectType,
                    origin: ObjectID,
                    target: ObjectID) -> MutableObject {

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
                           components: [any Component] = []) -> MutableObject {
        precondition(type.structuralType == .edge, "Structural type mismatch")
        precondition(contains(origin), "Missing edge origin")
        precondition(contains(target), "Missing edge target")

        let snapshot = mutableFrame.create(type,
            structure: .edge(origin, target),
            attributes: attributes,
            components: components)
        
        return snapshot
    }
                     
                     @discardableResult
    public func createEdge(_ type: ObjectType,
                           origin: any ObjectSnapshot,
                           target: any ObjectSnapshot,
                           attributes: [String:Variant] = [:],
                           components: [any Component] = []) -> MutableObject {
        precondition(type.structuralType == .edge, "Structural type mismatch")
        precondition(contains(origin.id), "Missing edge origin")
        precondition(contains(target.id), "Missing edge target")
        
        let snapshot = mutableFrame.create(type,
                                           structure: .edge(origin.id, target.id),
                                           attributes: attributes,
                                           components: components)
        
        return snapshot
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
                           components: [any Component] = []) -> MutableObject {
            precondition(type.structuralType == .node, "Structural type mismatch")

        var actualAttributes = attributes
        
        if let name {
            actualAttributes["name"] = Variant(name)
        }
        
        let snapshot = mutableFrame.create(
            type,
            attributes: actualAttributes,
            components: components
        )

        return snapshot
    }

    public func remove(node nodeID: ObjectID) {
        self.mutableFrame.removeCascading(nodeID)
    }
    
    public func remove(edge edgeID: ObjectID) {
        self.mutableFrame.removeCascading(edgeID)
    }
}
